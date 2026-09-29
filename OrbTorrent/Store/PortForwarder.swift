import Foundation
import Observation

/// Gets a port forwarded by the VPN downloads go through, so peers can
/// connect in, and has the engine listen on it.
///
/// The port comes, in order, from the settings (for VPNs where a port is
/// reserved in the account, such as AirVPN or Windscribe), from the VPN's
/// gateway over NAT-PMP (ProtonVPN, hide.me), or from Private Internet
/// Access's app.
/// While a port is forwarded, the engine's own listening port and router port
/// mapping are set aside, and put back afterwards.
@MainActor
@Observable
final class PortForwarder {
    enum Status: Equatable {
        /// Not downloading through a VPN.
        case off
        case searching
        /// Peers reach this Mac on this port, forwarded by the named source.
        case forwarded(port: Int, by: String)
        /// The VPN doesn't forward a port, or not yet.
        case unavailable
    }

    private(set) var status: Status = .off
    /// Called after the engine's listening port changes.
    @ObservationIgnored var onEngineSettingsChanged: (() -> Void)?

    private let settings: AppSettings
    private let engine: EngineController
    private let defaults: UserDefaults
    @ObservationIgnored private var connection: VPNMonitor.Connection?
    @ObservationIgnored private var task: Task<Void, Never>?
    /// The gateway that answered last, asked first next time.
    @ObservationIgnored private var gateway: String?

    /// NAT-PMP mappings last a minute; renew them well before.
    private static let renewal: Duration = .seconds(45)
    /// How long a VPN that has just connected gets to settle: its first
    /// packets wait on its handshake, and its details arrive in steps.
    private static let settling: Duration = .seconds(1.5)
    /// How long to wait before asking a VPN that didn't forward a port again:
    /// soon at first, as a VPN that has just connected can miss a request.
    private static let retries: [Duration] = [.seconds(5), .seconds(15), .seconds(30), .seconds(60)]
    private static let savedKey = "listeningBeforePortForwarding"

    init(settings: AppSettings, engine: EngineController, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.engine = engine
        self.defaults = defaults
    }

    /// What getting no forwarded port means, and for ProtonVPN, which only
    /// forwards one when set up to, how to get one.
    nonisolated static func noPortExplanation(forVPNNamed name: String) -> String {
        let meaning = "Only peers with open ports can connect to you."
        guard name.localizedCaseInsensitiveContains("proton") else { return meaning }
        return meaning + " For a port, turn on port forwarding in ProtonVPN's settings and connect to a P2P server."
            + " It needs a paid plan."
    }

    /// The listening port and router port mapping set aside while a port is
    /// forwarded, to show and put back.
    var setAside: (port: Int, portMapping: Bool)? {
        guard let saved = defaults.dictionary(forKey: Self.savedKey),
              let port = saved["port"] as? Int, let portMapping = saved["portMapping"] as? Bool
        else { return nil }
        return (port, portMapping)
    }

    /// Forwards a port for the VPN downloads go through, or stops when there's none.
    func follow(_ connection: VPNMonitor.Connection?) async {
        guard connection != self.connection || (connection != nil && task == nil) else { return }
        self.connection = connection
        await restart()
    }

    /// Starts again, after the forwarded port setting changes or the engine restarts.
    func restart() async {
        task?.cancel()
        task = nil
        guard let connection else {
            status = .off
            await putBackListening()
            return
        }
        task = Task { [weak self] in await self?.run(connection) }
    }

    private func run(_ connection: VPNMonitor.Connection) async {
        status = .searching
        try? await Task.sleep(for: Self.settling)
        var misses = 0
        // When the port last forwarded stops being forwarded, unless renewed.
        var lapses: ContinuousClock.Instant?
        while !Task.isCancelled {
            if case let (port, source)? = await findPort(for: connection) {
                guard !Task.isCancelled else { return }
                misses = 0
                lapses = .now + .seconds(NATPMP.lifetime)
                await listen(on: port)
                status = .forwarded(port: port, by: source)
                try? await Task.sleep(for: Self.renewal)
            } else {
                guard !Task.isCancelled else { return }
                // A missed renewal isn't the end: the port stays forwarded
                // until its mapping runs out. After that, the engine goes back
                // to its own port.
                if lapses.map({ .now >= $0 }) ?? true {
                    lapses = nil
                    status = .unavailable
                    await putBackListening()
                }
                try? await Task.sleep(for: Self.retries[min(misses, Self.retries.count - 1)])
                misses += 1
            }
        }
    }

    // MARK: Finding the port

    private func findPort(for connection: VPNMonitor.Connection) async -> (Int, String)? {
        if let port = settings.vpnForwardedPort, (1...65_535).contains(port) {
            return (port, "your VPN account")
        }
        let candidates = [gateway].compactMap { $0 }
            + NATPMP.gatewayCandidates(router: connection.router, address: connection.address)
        // A gateway that forwards the port asked for is asked for the one the
        // engine listens on: the one forwarded before, or the person's own.
        let preferred = (try? await engine.client.preferences()).flatMap { UInt16(exactly: $0.listenPort) }
        let answer = await Task.detached { () -> (UInt16, String)? in
            for candidate in candidates {
                if let port = NATPMP.forwardPort(gateway: candidate, interface: connection.interface,
                                                 preferring: preferred) {
                    return (port, candidate)
                }
            }
            return nil
        }.value
        if case let (port, answering)? = answer {
            gateway = answering
            return (Int(port), connection.name)
        }
        if let port = await Task.detached(operation: { PIAControl.forwardedPort() }).value {
            return (Int(port), "Private Internet Access")
        }
        return nil
    }

    // MARK: The engine's listening port

    private func listen(on port: Int) async {
        guard engine.isRunning, let preferences = try? await engine.client.preferences() else { return }
        if setAside == nil {
            defaults.set(["port": preferences.listenPort, "portMapping": preferences.portMapping], forKey: Self.savedKey)
        }
        guard preferences.listenPort != port || preferences.portMapping else { return }
        // The router's port mapping is no use through a VPN, and the VPN asks
        // for the listening port to be its forwarded one.
        try? await engine.changeListening(["listen_port": .int(Int64(port)), "upnp": .bool(false)])
        onEngineSettingsChanged?()
    }

    private func putBackListening() async {
        guard let saved = setAside, engine.isRunning else { return }
        do {
            try await engine.changeListening(["listen_port": .int(Int64(saved.port)), "upnp": .bool(saved.portMapping)])
            defaults.removeObject(forKey: Self.savedKey)
            onEngineSettingsChanged?()
        } catch {
            // Put back the next time forwarding stops or OrbTorrent starts.
        }
    }
}
