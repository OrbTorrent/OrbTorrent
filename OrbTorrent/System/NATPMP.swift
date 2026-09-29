import Darwin
import Foundation

/// Asks a VPN's gateway to forward a port to this Mac, over NAT-PMP
/// (RFC 6886). ProtonVPN's gateway picks the public port and forwards it to
/// the same port here; other gateways, such as hide.me's, forward the port
/// asked for.
enum NATPMP {
    static let gatewayPort: UInt16 = 5351
    /// Mappings last this long and are renewed before they run out.
    static let lifetime: UInt32 = 60

    enum PortProtocol: UInt8 {
        case udp = 1
        case tcp = 2
    }

    struct Mapping: Equatable, Sendable {
        let internalPort: UInt16
        let publicPort: UInt16
        let lifetime: UInt32
    }

    enum Answer: Equatable, Sendable {
        case mapped(Mapping)
        /// The gateway answered, but won't map the port.
        case refused
        /// Nothing answered: there's no NAT-PMP gateway there.
        case none
    }

    /// A request for the gateway's public address, which ProtonVPN's
    /// documented client (natpmpc) and gluetun send before asking for a port.
    static let addressRequest: [UInt8] = [0, 0]

    /// Whether a response answers the public address request, successfully
    /// or not: either way, the gateway speaks NAT-PMP.
    static func answersAddressRequest(_ response: [UInt8]) -> Bool {
        response.count >= 4 && response[0] == 0 && response[1] == 128
    }

    /// A request for a mapping. By default it's the way ProtonVPN documents,
    /// letting the gateway choose the port: internal port 0, suggested
    /// public port 1. A lifetime of 0 removes the mapping.
    static func mappingRequest(_ portProtocol: PortProtocol, internalPort: UInt16 = 0, suggestedPort: UInt16 = 1,
                               lifetime: UInt32 = lifetime) -> [UInt8] {
        [0, portProtocol.rawValue, 0, 0] + bytes(internalPort) + bytes(suggestedPort) + bytes(lifetime)
    }

    /// What a gateway's response says, or nil when it isn't a response to a
    /// request for that protocol.
    static func answer(from response: [UInt8], for portProtocol: PortProtocol) -> Answer? {
        guard response.count >= 4, response[0] == 0, response[1] == 128 + portProtocol.rawValue else { return nil }
        guard uint16(response, at: 2) == 0, response.count >= 16 else { return .refused }
        let mapping = Mapping(internalPort: uint16(response, at: 8), publicPort: uint16(response, at: 10),
                              lifetime: uint32(response, at: 12))
        return mapping.publicPort == 0 ? .refused : .mapped(mapping)
    }

    /// Gets a port forwarded to the same port on this Mac, for UDP and TCP.
    /// Blocks while it asks, so call it off the main thread.
    ///
    /// It asks for the gateway's public address, then for a port as ProtonVPN
    /// documents. A gateway that refuses that is asked the standard way, for
    /// `preferred` on both sides, and if it offers another port instead, for
    /// that one on both sides.
    static func forwardPort(gateway: String, port: UInt16 = gatewayPort, interface: String?,
                            preferring preferred: UInt16?) -> UInt16? {
        func ask(_ portProtocol: PortProtocol, _ internalPort: UInt16 = 0, _ suggestedPort: UInt16 = 1,
                 lifetime: UInt32 = lifetime) -> Answer {
            requestMapping(portProtocol, gateway: gateway, port: port, interface: interface,
                           internalPort: internalPort, suggestedPort: suggestedPort, lifetime: lifetime)
        }
        // A gateway that doesn't answer has no NAT-PMP.
        guard exchange(addressRequest, gateway: gateway, port: port, interface: interface,
                       read: { answersAddressRequest($0) ? true : nil }) != nil
        else { return nil }
        switch ask(.udp) {
        case .none:
            return nil
        case .mapped(let udp):
            // ProtonVPN wants both, and gives both the same port.
            guard case .mapped = ask(.tcp) else { return nil }
            return udp.publicPort
        case .refused:
            break
        }
        guard var wanted = preferred, wanted != 0 else { return nil }
        for _ in 0..<2 {
            guard case .mapped(let udp) = ask(.udp, wanted, wanted) else { return nil }
            guard udp.publicPort == wanted else {
                // Let go of the offer, which holds the port, and ask for it on both sides.
                _ = ask(.udp, wanted, 0, lifetime: 0)
                wanted = udp.publicPort
                continue
            }
            guard case .mapped(let tcp) = ask(.tcp, wanted, wanted), tcp.publicPort == wanted else { return nil }
            return wanted
        }
        return nil
    }

    /// Where a VPN's gateway may be: its router when that isn't this Mac's own
    /// address, ProtonVPN's gateway, and the first addresses of its network.
    static func gatewayCandidates(router: String?, address: String?) -> [String] {
        var candidates: [String] = []
        if let router, router != address { candidates.append(router) }
        candidates.append("10.2.0.1")
        if let octets = address?.split(separator: "."), octets.count == 4 {
            candidates.append("\(octets[0]).\(octets[1]).\(octets[2]).1")
            candidates.append("\(octets[0]).\(octets[1]).0.1")
        }
        var seen: Set<String> = []
        return candidates.filter { $0 != address && seen.insert($0).inserted }
    }

    /// Asks a gateway for a mapping, sending over the given interface. Blocks
    /// for up to `timeout` per attempt, so call it off the main thread.
    static func requestMapping(_ portProtocol: PortProtocol, gateway: String, port: UInt16 = gatewayPort,
                               interface: String?, internalPort: UInt16 = 0, suggestedPort: UInt16 = 1,
                               lifetime: UInt32 = lifetime, attempts: Int = 2, timeout: TimeInterval = 0.5) -> Answer {
        let request = mappingRequest(portProtocol, internalPort: internalPort, suggestedPort: suggestedPort,
                                     lifetime: lifetime)
        return exchange(request, gateway: gateway, port: port, interface: interface, attempts: attempts,
                        timeout: timeout, read: { answer(from: $0, for: portProtocol) }) ?? .none
    }

    /// Sends a request to a gateway over the given interface, and returns the
    /// first response from it that `read` understands, or nil when none comes.
    private static func exchange<Reply>(_ request: [UInt8], gateway: String, port: UInt16, interface: String?,
                                        attempts: Int = 2, timeout: TimeInterval = 0.5,
                                        read: ([UInt8]) -> Reply?) -> Reply? {
        let socket = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socket >= 0 else { return nil }
        defer { close(socket) }

        // Through the VPN only, never the normal connection.
        if let interface {
            var index = if_nametoindex(interface)
            guard index != 0,
                  setsockopt(socket, IPPROTO_IP, IP_BOUND_IF, &index, socklen_t(MemoryLayout<UInt32>.size)) == 0
            else { return nil }
        }
        var wait = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - timeout.rounded(.down)) * 1_000_000))
        setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &wait, socklen_t(MemoryLayout<timeval>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = port.bigEndian
        guard inet_pton(AF_INET, gateway, &address.sin_addr) == 1 else { return nil }

        for _ in 0..<attempts {
            let sent = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(socket, request, request.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard sent == request.count else { return nil }
            var buffer = [UInt8](repeating: 0, count: 16)
            var sender = sockaddr_in()
            var senderLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = withUnsafeMutablePointer(to: &sender) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socket, &buffer, buffer.count, 0, $0, &senderLength)
                }
            }
            if received > 0, sender.sin_addr.s_addr == address.sin_addr.s_addr,
               let reply = read(Array(buffer.prefix(received))) {
                return reply
            }
        }
        return nil
    }

    private static func bytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }

    private static func uint16(_ bytes: [UInt8], at offset: Int) -> UInt16 {
        UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    private static func uint32(_ bytes: [UInt8], at offset: Int) -> UInt32 {
        (0..<4).reduce(0) { $0 << 8 | UInt32(bytes[offset + $1]) }
    }
}
