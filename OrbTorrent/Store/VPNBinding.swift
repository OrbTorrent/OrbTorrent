import Foundation
import Observation

/// Keeps the engine on the VPN when the settings say to download only through
/// one. The engine then uses nothing but the VPN's network interface, so if the
/// VPN drops it stops rather than falling back to the normal connection.
@MainActor
@Observable
final class VPNBinding {
    enum Status: Equatable {
        /// Downloads use any connection.
        case off
        /// Downloads go through this VPN.
        case through(VPNMonitor.Connection)
        /// Downloads wait: no VPN (or not the chosen one) is connected.
        case waitingForVPN
    }

    /// An interface name that can't exist, for when no VPN is connected: bound
    /// to it, the engine has no connection at all.
    static let noVPN = "orbtorrent-no-vpn"

    let monitor = VPNMonitor()
    let ports: PortForwarder
    private(set) var status: Status = .off

    private let settings: AppSettings
    private let engine: EngineController
    /// The interface last given to the running engine.
    @ObservationIgnored private var applied: String?
    /// Drops the engine's connections to peers, so none carries on over a
    /// network the engine may no longer use.
    @ObservationIgnored var reconnectPeers: (() async -> Void)?

    init(settings: AppSettings, engine: EngineController) {
        self.settings = settings
        self.engine = engine
        ports = PortForwarder(settings: settings, engine: engine)
        monitor.onChange = { [weak self] in
            Task { await self?.apply() }
        }
        updateStatus()
    }

    /// The interface the engine should use: empty for any.
    static func interface(vpnOnly: Bool, connection: VPNMonitor.Connection?) -> String {
        guard vpnOnly else { return "" }
        return connection?.interface ?? noVPN
    }

    /// Whether the engine could be left with connections on a network it may
    /// no longer use, as it keeps the ones it has when it moves: moving to a
    /// narrower choice, such as the VPN after any network, from one it had
    /// connections on. `previous` is nil for an engine that has just started.
    static func leavesStrayConnections(movingFrom previous: String?, to interface: String) -> Bool {
        guard let previous, previous != noVPN else { return false }
        return !interface.isEmpty
    }

    /// The interface for the engine to start with, written to its settings
    /// before it launches, so it never starts on the wrong connection.
    var interfaceForLaunch: String {
        Self.interface(vpnOnly: settings.vpnOnly, connection: monitor.connection(for: settings.vpnServiceID))
    }

    /// Moves the running engine to the right interface, after the setting,
    /// the chosen VPN or the connected VPNs change, or the engine starts.
    func apply() async {
        updateStatus()
        let interface = interfaceForLaunch
        if engine.isRunning, interface != applied {
            do {
                let previous = applied
                try await engine.changeListening([
                    "current_network_interface": .string(interface),
                    "current_interface_address": .string(""),
                ])
                applied = interface
                if Self.leavesStrayConnections(movingFrom: previous, to: interface) {
                    await reconnectPeers?()
                }
            } catch {
                // Retried on the next change; the engine keeps its last binding.
            }
        }
        guard engine.isRunning else { return }
        if case .through(let connection) = status {
            await ports.follow(connection)
        } else {
            await ports.follow(nil)
        }
    }

    /// Gives a newly started engine the interface again, in case a VPN
    /// connected or dropped while it was starting.
    func engineDidStart() async {
        applied = nil
        await apply()
        await ports.restart()
    }

    private func updateStatus() {
        let status: Status
        if !settings.vpnOnly {
            status = .off
        } else if let connection = monitor.connection(for: settings.vpnServiceID) {
            status = .through(connection)
        } else {
            status = .waitingForVPN
        }
        if status != self.status { self.status = status }
    }
}
