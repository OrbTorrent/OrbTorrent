import Darwin
import Foundation
import Testing
@testable import OrbTorrent

struct PortForwardingTests {
    @Test func asksForAMappingTheWayProtonVPNDocumentsIt() {
        // natpmpc -a 1 0 tcp 60: internal port 0, suggested public port 1, 60 seconds.
        #expect(NATPMP.mappingRequest(.tcp) == [0, 2, 0, 0, 0, 0, 0, 1, 0, 0, 0, 60])
        #expect(NATPMP.mappingRequest(.udp)[1] == 1)
    }

    @Test func asksForThePublicAddressFirstAsProtonsClientDoes() {
        #expect(NATPMP.addressRequest == [0, 0])
        #expect(NATPMP.answersAddressRequest([0, 128, 0, 0, 0, 0, 0, 1, 185, 150, 0, 72]))
        // Refused still means a NAT-PMP gateway is there.
        #expect(NATPMP.answersAddressRequest([0, 128, 0, 3, 0, 0, 0, 1]))
        #expect(!NATPMP.answersAddressRequest([0, 130, 0, 0, 0, 0, 0, 1]))
    }

    @Test func asksForItsOwnPortTheStandardWay() {
        #expect(NATPMP.mappingRequest(.udp, internalPort: 51_413, suggestedPort: 51_413)
            == [0, 1, 0, 0, 0xC8, 0xD5, 0xC8, 0xD5, 0, 0, 0, 60])
    }

    @Test func readsTheForwardedPort() {
        let answer: [UInt8] = [0, 130, 0, 0, 0, 0, 1, 0, 0, 0, 0xC8, 0xD5, 0, 0, 0, 60]
        #expect(NATPMP.answer(from: answer, for: .tcp)
            == .mapped(NATPMP.Mapping(internalPort: 0, publicPort: 51_413, lifetime: 60)))
    }

    @Test func tellsRefusalsFromAnswersToOtherRequests() {
        let refused: [UInt8] = [0, 130, 0, 2, 0, 0, 1, 0]
        let forUDP: [UInt8] = [0, 129, 0, 0, 0, 0, 1, 0, 0, 0, 0xC8, 0xD5, 0, 0, 0, 60]
        #expect(NATPMP.answer(from: refused, for: .tcp) == .refused)
        #expect(NATPMP.answer(from: forUDP, for: .tcp) == nil)
        #expect(NATPMP.answer(from: [0, 130], for: .tcp) == nil)
    }

    @Test func triesTheVPNsRouterThenLikelyGateways() {
        #expect(NATPMP.gatewayCandidates(router: "10.2.0.1", address: "10.2.0.2") == ["10.2.0.1"])
        #expect(NATPMP.gatewayCandidates(router: "10.96.0.1", address: "10.96.4.9") == ["10.96.0.1", "10.2.0.1", "10.96.4.1"])
        // A router that is this Mac's own address, as some VPN apps report, is skipped.
        #expect(NATPMP.gatewayCandidates(router: "10.8.3.7", address: "10.8.3.7") == ["10.2.0.1", "10.8.3.1", "10.8.0.1"])
        #expect(NATPMP.gatewayCandidates(router: nil, address: nil) == ["10.2.0.1"])
    }

    @Test func getsThePortProtonVPNHandsOut() async throws {
        let gateway = try FakeGateway(.proton(publicPort: 51_413))
        defer { gateway.stop() }
        #expect(await forward(through: gateway, preferring: 6_881) == 51_413)
    }

    @Test func getsItsOwnPortFromAStandardGateway() async throws {
        let gateway = try FakeGateway(.standard(taken: []))
        defer { gateway.stop() }
        #expect(await forward(through: gateway, preferring: 6_881) == 6_881)
    }

    @Test func takesTheOfferedPortOnBothSidesWhenItsOwnIsTaken() async throws {
        let gateway = try FakeGateway(.standard(taken: [6_881]))
        defer { gateway.stop() }
        #expect(await forward(through: gateway, preferring: 6_881) == 6_882)
    }

    @Test func givesUpOnAGatewayThatDoesntAnswer() async {
        let answer = await Task.detached {
            NATPMP.requestMapping(.tcp, gateway: "127.0.0.1", port: 9, interface: "lo0", attempts: 1, timeout: 0.2)
        }.value
        #expect(answer == NATPMP.Answer.none)
    }

    private func forward(through gateway: FakeGateway, preferring preferred: UInt16) async -> UInt16? {
        await Task.detached {
            NATPMP.forwardPort(gateway: "127.0.0.1", port: gateway.port, interface: "lo0", preferring: preferred)
        }.value
    }

    @Test func tellsProtonUsersHowToGetAPort() {
        #expect(PortForwarder.noPortExplanation(forVPNNamed: "ProtonVPN").contains("P2P server"))
        #expect(PortForwarder.noPortExplanation(forVPNNamed: "your VPN") == "Only peers with open ports can connect to you.")
    }

    @Test func readsPrivateInternetAccessPorts() {
        #expect(PIAControl.parse("51413\n") == 51_413)
        for status in ["Inactive", "Attempting", "Failed", "Unavailable", ""] {
            #expect(PIAControl.parse(status) == nil)
        }
    }
}

/// A NAT-PMP gateway on the loopback interface.
private final class FakeGateway: @unchecked Sendable {
    enum Kind: Sendable {
        /// Like ProtonVPN's: every request gets the same public port, forwarded to the same port.
        case proton(publicPort: UInt16)
        /// Like a router's or hide.me's: forwards the port asked for, offers
        /// the next free one when it's taken, and refuses internal port 0.
        case standard(taken: Set<UInt16>)
    }

    let port: UInt16
    private let socket: Int32

    init(_ kind: Kind) throws {
        let socket = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bound = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socket, $0, length) == 0 && getsockname(socket, $0, &length) == 0
            }
        }
        guard bound else { throw CocoaError(.fileWriteUnknown) }
        self.socket = socket
        port = UInt16(bigEndian: address.sin_port)
        Thread.detachNewThread {
            var request = [UInt8](repeating: 0, count: 12)
            var client = sockaddr_in()
            var clientLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            // Public port by protocol and internal port.
            var mappings: [[UInt8]: UInt16] = [:]
            while true {
                let received = withUnsafeMutablePointer(to: &client) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { recvfrom(socket, &request, 12, 0, $0, &clientLength) }
                }
                guard received > 0 else { return }
                if received == 2, request[1] == 0 {
                    // The public address: 127.0.0.1.
                    let answer: [UInt8] = [0, 128, 0, 0, 0, 0, 0, 1, 127, 0, 0, 1]
                    _ = withUnsafePointer(to: &client) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(socket, answer, answer.count, 0, $0, clientLength) }
                    }
                    continue
                }
                guard received == 12 else { return }
                let internalPort = UInt16(request[4]) << 8 | UInt16(request[5])
                let suggested = UInt16(request[6]) << 8 | UInt16(request[7])
                let lifetime = request[8...11].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
                var result: UInt8 = 0
                var publicPort: UInt16 = 0
                switch kind {
                case .proton(let port):
                    publicPort = port
                case .standard(let taken):
                    let key = [request[1], request[4], request[5]]
                    if lifetime == 0 {
                        mappings[key] = nil
                    } else if internalPort == 0 {
                        result = 2
                    } else {
                        let inUse = taken.union(mappings.filter { $0.key[0] == request[1] && $0.key != key }.values)
                        publicPort = suggested == 0 ? internalPort : suggested
                        while inUse.contains(publicPort) { publicPort += 1 }
                        mappings[key] = publicPort
                    }
                }
                let answer: [UInt8] = [0, 128 + request[1], 0, result, 0, 0, 0, 1, request[4], request[5],
                                       UInt8(publicPort >> 8), UInt8(publicPort & 0xFF), request[8], request[9], request[10], request[11]]
                _ = withUnsafePointer(to: &client) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(socket, answer, answer.count, 0, $0, clientLength) }
                }
            }
        }
    }

    func stop() {
        Darwin.shutdown(socket, SHUT_RDWR)
        close(socket)
    }
}
