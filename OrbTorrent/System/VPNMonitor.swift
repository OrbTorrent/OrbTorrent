import Darwin
import Foundation
import Observation
import SystemConfiguration

/// The VPNs set up on this Mac, and which are connected, from the system's
/// network state and routing table. It updates as VPNs connect and disconnect.
@MainActor
@Observable
final class VPNMonitor {
    /// A VPN set up in System Settings or by a VPN app.
    struct Service: Identifiable, Hashable, Sendable {
        let id: String
        let name: String
    }

    /// A connected VPN and the network interface it uses.
    struct Connection: Equatable, Sendable {
        let serviceID: String?
        let name: String
        let interface: String
        let address: String?
        let router: String?
    }

    /// VPNs set up on this Mac, by name.
    private(set) var services: [Service] = []
    /// The connected VPN that carries internet traffic, if any. A VPN such as
    /// Tailscale that only reaches some addresses doesn't count.
    private(set) var primary: Connection?
    /// Every connected VPN, including ones that only carry some traffic.
    private(set) var connected: [Connection] = []

    /// Called after anything changes.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private var store: SCDynamicStore?
    /// Each VPN service's connection, by ID, to ask for and watch its state.
    @ObservationIgnored private var sessions: [String: SCNetworkConnection] = [:]
    @ObservationIgnored private var routeChanges: DispatchSourceRead?
    @ObservationIgnored private var updatePending = false

    init() {
        var context = SCDynamicStoreContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                            retain: nil, release: nil, copyDescription: nil)
        store = SCDynamicStoreCreate(nil, "OrbTorrent" as CFString, { _, _, info in
            guard let info else { return }
            let monitor = Unmanaged<VPNMonitor>.fromOpaque(info).takeUnretainedValue()
            // Delivered on the main queue, set below.
            MainActor.assumeIsolated { monitor.update() }
        }, &context)
        if let store {
            SCDynamicStoreSetNotificationKeys(
                store,
                ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"] as CFArray,
                ["State:/Network/Service/.*/IPv4", "Setup:/Network/Service/.*"] as CFArray
            )
            SCDynamicStoreSetDispatchQueue(store, .main)
        }
        watchRoutes()
        update()
    }

    /// The VPN to download through: the chosen one if it's connected, or with
    /// no choice, whichever VPN carries internet traffic.
    func connection(for serviceID: String?) -> Connection? {
        guard let serviceID else { return primary }
        return connected.first { $0.serviceID == serviceID }
    }

    /// What a connected VPN with no name of its own is called.
    static let unnamed = "your VPN"

    /// Whether an interface is a tunnel, as VPNs use.
    nonisolated static func isTunnel(_ interface: String) -> Bool {
        ["utun", "ipsec", "ppp", "tun", "tap", "wg", "gpd"].contains { interface.hasPrefix($0) }
    }

    /// The interface this Mac reaches the internet through, and its address,
    /// from the routing table.
    nonisolated static func internetRoute() -> (interface: String, address: String)? {
        let probe = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard probe >= 0 else { return nil }
        defer { close(probe) }
        var remote = sockaddr_in()
        remote.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        remote.sin_family = sa_family_t(AF_INET)
        remote.sin_port = in_port_t(53).bigEndian
        remote.sin_addr.s_addr = inet_addr("1.1.1.1")
        var local = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        // Connecting a UDP socket sends nothing; it only picks the route.
        let routed = withUnsafePointer(to: &remote) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(probe, $0, length) == 0 }
        } && withUnsafeMutablePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(probe, $0, &length) == 0 }
        }
        guard routed, local.sin_addr.s_addr != 0 else { return nil }

        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let interfaces else { return nil }
        defer { freeifaddrs(interfaces) }
        for entry in sequence(first: interfaces, next: { $0.pointee.ifa_next }) {
            guard let address = entry.pointee.ifa_addr, address.pointee.sa_family == sa_family_t(AF_INET),
                  address.withMemoryRebound(to: sockaddr_in.self, capacity: 1, { $0.pointee.sin_addr.s_addr })
                    == local.sin_addr.s_addr
            else { continue }
            var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &local.sin_addr, &text, socklen_t(text.count))
            return (String(cString: entry.pointee.ifa_name), text.withUnsafeBufferPointer { String(cString: $0.baseAddress!) })
        }
        return nil
    }

    /// Whether a message from the routing socket may change which interface
    /// carries internet traffic: a route or address added, changed or removed.
    /// Routes cloned for each destination and link-layer entries don't.
    nonisolated static func changesRouting(_ message: some Collection<UInt8>) -> Bool {
        // rt_msghdr: length (2 bytes), version, type, index (2), padding (2), flags (4).
        let bytes = Array(message.prefix(12))
        guard bytes.count >= 4 else { return false }
        switch Int32(bytes[3]) {
        case RTM_NEWADDR, RTM_DELADDR:
            return true
        case RTM_ADD, RTM_DELETE, RTM_CHANGE:
            guard bytes.count == 12 else { return false }
            let flags = bytes[8..<12].withUnsafeBytes { Int32(littleEndian: $0.loadUnaligned(as: Int32.self)) }
            return flags & (RTF_WASCLONED | RTF_LLINFO) == 0
        default:
            return false
        }
    }

    // MARK: Reading the network state

    /// Watches the routing table, as VPNs that route all traffic through
    /// themselves without becoming the primary service change nothing else.
    private func watchRoutes() {
        let socket = Darwin.socket(PF_ROUTE, SOCK_RAW, AF_UNSPEC)
        guard socket >= 0 else { return }
        _ = fcntl(socket, F_SETFL, O_NONBLOCK)
        let source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: .main)
        source.setEventHandler { [weak self] in
            var message = [UInt8](repeating: 0, count: 2048)
            var changed = false
            while true {
                let count = read(socket, &message, message.count)
                guard count > 0 else { break }
                changed = changed || Self.changesRouting(message.prefix(count))
            }
            guard changed else { return }
            MainActor.assumeIsolated { self?.updateSoon() }
        }
        source.setCancelHandler { close(socket) }
        source.resume()
        routeChanges = source
    }

    /// Updates once a burst of route changes has settled.
    private func updateSoon() {
        guard !updatePending else { return }
        updatePending = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.updatePending = false
            self?.update()
        }
    }

    private func update() {
        guard let store else { return }
        let services = vpnServices(store)
        watchSessions(of: services)
        let connected = connections(of: services, in: store)
        let primary = primaryConnection(in: store, connected: connected)
        guard services != self.services || connected != self.connected || primary != self.primary else { return }
        self.services = services
        self.connected = connected
        self.primary = primary
        onChange?()
    }

    private func vpnServices(_ store: SCDynamicStore) -> [Service] {
        let keys = SCDynamicStoreCopyKeyList(store, "Setup:/Network/Service/[^/]+/Interface" as CFString) as? [String] ?? []
        return keys.compactMap { key -> Service? in
            guard let interface = value(key, in: store) else { return nil }
            let type = interface["Type"] as? String
            let subType = interface["SubType"] as? String
            // PPP is also PPPoE, which isn't a VPN.
            guard type == "VPN" || type == "IPSec" || (type == "PPP" && ["L2TP", "PPTP"].contains(subType ?? "")) else { return nil }
            let id = key.split(separator: "/")[3]
            let name = value("Setup:/Network/Service/\(id)", in: store)?["UserDefinedName"] as? String
            return Service(id: String(id), name: name ?? "VPN")
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func connections(of services: [Service], in store: SCDynamicStore) -> [Connection] {
        // A VPN that an app runs, such as WireGuard or ProtonVPN, has its state
        // filed under an ID of its own, not the service's. Those need asking.
        let states = SCDynamicStoreCopyKeyList(store, "State:/Network/Service/[^/]+/IPv4" as CFString) as? [String] ?? []
        let appRun = states.contains { key in value("Setup:/Network/Service/\(key.split(separator: "/")[3])", in: store) == nil }
        return services.compactMap { service in
            let ipv4 = value("State:/Network/Service/\(service.id)/IPv4", in: store)
                ?? (appRun ? sessionIPv4(of: service) : nil)
            guard let ipv4, let interface = ipv4["InterfaceName"] as? String else { return nil }
            return Connection(serviceID: service.id, name: service.name, interface: interface,
                              address: (ipv4["Addresses"] as? [String])?.first, router: ipv4["Router"] as? String)
        }
    }

    /// Watches each VPN's status, as a VPN an app runs can become connected
    /// after its network state is set, with nothing else changing.
    private func watchSessions(of services: [Service]) {
        let ids = Set(services.map(\.id))
        for (id, session) in sessions where !ids.contains(id) {
            SCNetworkConnectionSetDispatchQueue(session, nil)
            sessions[id] = nil
        }
        for id in ids where sessions[id] == nil {
            var context = SCNetworkConnectionContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                                     retain: nil, release: nil, copyDescription: nil)
            guard let session = SCNetworkConnectionCreateWithServiceID(nil, id as CFString, { _, _, info in
                guard let info else { return }
                let monitor = Unmanaged<VPNMonitor>.fromOpaque(info).takeUnretainedValue()
                // Delivered on the main queue, set below.
                MainActor.assumeIsolated { monitor.update() }
            }, &context) else { continue }
            SCNetworkConnectionSetDispatchQueue(session, .main)
            sessions[id] = session
        }
    }

    /// The network state of a VPN an app runs, once it has one.
    private func sessionIPv4(of service: Service) -> [String: Any]? {
        guard let session = sessions[service.id],
              [.connecting, .connected].contains(SCNetworkConnectionGetStatus(session))
        else { return nil }
        return (SCNetworkConnectionCopyExtendedStatus(session) as? [String: Any])?["IPv4"] as? [String: Any]
    }

    private func primaryConnection(in store: SCDynamicStore, connected: [Connection]) -> Connection? {
        let global = value("State:/Network/Global/IPv4", in: store) ?? value("State:/Network/Global/IPv6", in: store)
        let primaryInterface = global?["PrimaryInterface"] as? String
        // The routing table has the last word: OpenVPN and wg-quick send all
        // traffic through the VPN with routes of their own, leaving the
        // primary service as it was.
        let route = Self.internetRoute()
        guard let interface = route?.interface ?? primaryInterface, Self.isTunnel(interface) else { return nil }
        if let known = connected.first(where: { $0.interface == interface }) { return known }
        // A tunnel that isn't set up as a VPN service, such as one Tunnelblick
        // or wg-quick made. There's no name to show, so it's "your VPN".
        return Connection(serviceID: nil, name: Self.unnamed, interface: interface, address: route?.address,
                          router: interface == primaryInterface ? global?["Router"] as? String : nil)
    }

    private func value(_ key: String, in store: SCDynamicStore) -> [String: Any]? {
        SCDynamicStoreCopyValue(store, key as CFString) as? [String: Any]
    }
}
