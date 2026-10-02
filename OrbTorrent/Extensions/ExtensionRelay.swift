import Foundation
import Network

/// Extensions' requests go through this relay, a proxy on 127.0.0.1 that only
/// OrbTorrent uses. URLSession asks it to CONNECT to a host, and it looks the
/// host up itself and connects to the very address it checked. So a host
/// can't pass the check with an address on the internet, then switch to one on
/// this Mac or the local network for the connection (DNS rebinding).
///
/// It only relays bytes: TLS runs from URLSession to the host, through it.
final class ExtensionRelay: @unchecked Sendable {
    static let shared = ExtensionRelay()

    /// Looks up a host's addresses; replaced in tests.
    let resolve: @Sendable (String) async -> [String]

    private let queue = DispatchQueue(label: "OrbTorrent.extension-relay")
    // Only touched on `queue`.
    private var listener: NWListener?
    private var port: UInt16?
    private var waiters: [CheckedContinuation<UInt16?, Never>] = []

    private static let maximumRequestHead = 8 << 10
    private static let chunk = 64 << 10

    init(resolve: @escaping @Sendable (String) async -> [String] = { await ExtensionNetwork.addresses(of: $0) }) {
        self.resolve = resolve
    }

    /// The port it listens on, starting it the first time; nil if it can't listen.
    func start() async -> UInt16? {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if let port { return continuation.resume(returning: port) }
                waiters.append(continuation)
                if listener == nil { listen() }
            }
        }
    }

    private func listen() {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        parameters.acceptLocalOnly = true
        guard let listener = try? NWListener(using: parameters) else { return finishStarting(nil) }
        self.listener = listener
        listener.stateUpdateHandler = { [weak self, weak listener] state in
            guard let self else { return }
            switch state {
            case .ready:
                finishStarting(listener?.port?.rawValue)
            case .failed, .cancelled:
                self.listener = nil
                port = nil
                finishStarting(nil)
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
    }

    private func finishStarting(_ port: UInt16?) {
        self.port = port
        for waiter in waiters { waiter.resume(returning: port) }
        waiters = []
    }

    // MARK: One connection

    private func accept(_ client: NWConnection) {
        client.start(queue: queue)
        readHead(of: client, buffer: Data())
    }

    /// Reads the CONNECT request, up to the blank line that ends it.
    private func readHead(of client: NWConnection, buffer: Data) {
        client.receive(minimumIncompleteLength: 1, maximumLength: Self.maximumRequestHead) { [weak self] data, _, isComplete, error in
            guard let self else { return client.cancel() }
            var buffer = buffer
            if let data { buffer.append(data) }
            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let head = String(decoding: buffer[..<end.lowerBound], as: UTF8.self)
                let early = Data(buffer[end.upperBound...])
                Task { await self.open(client, head: head, early: early) }
            } else if error != nil || isComplete || buffer.count > Self.maximumRequestHead {
                client.cancel()
            } else {
                readHead(of: client, buffer: buffer)
            }
        }
    }

    /// Connects to the host's checked address, or refuses.
    private func open(_ client: NWConnection, head: String, early: Data) async {
        guard let host = Self.host(inConnectRequest: head) else {
            return queue.async { self.refuse(client, "400 Bad Request") }
        }
        let addresses = await resolve(host)
        // The same rule as ExtensionNetwork's check: every address must be on the internet.
        guard let address = addresses.first, addresses.allSatisfy(NetworkAddress.isPublic) else {
            return queue.async { self.refuse(client, "403 Forbidden") }
        }
        queue.async { [self] in
            let options = NWProtocolTCP.Options()
            options.connectionTimeout = 15
            let upstream = NWConnection(host: NWEndpoint.Host(address), port: 443, using: NWParameters(tls: nil, tcp: options))
            upstream.stateUpdateHandler = { [weak self] state in
                guard let self else { return upstream.cancel() }
                switch state {
                case .ready:
                    upstream.stateUpdateHandler = nil
                    client.send(content: Data("HTTP/1.1 200 Connection Established\r\n\r\n".utf8), completion: .contentProcessed { error in
                        guard error == nil else { client.cancel(); upstream.cancel(); return }
                        if !early.isEmpty { upstream.send(content: early, completion: .idempotent) }
                        self.relay(from: client, to: upstream)
                        self.relay(from: upstream, to: client)
                    })
                case .failed, .waiting:
                    upstream.stateUpdateHandler = nil
                    upstream.cancel()
                    refuse(client, "502 Bad Gateway")
                default:
                    break
                }
            }
            upstream.start(queue: queue)
        }
    }

    /// Copies what one side sends to the other, a piece at a time, until either side closes.
    private func relay(from source: NWConnection, to target: NWConnection) {
        source.receive(minimumIncompleteLength: 1, maximumLength: Self.chunk) { [weak self] data, _, isComplete, error in
            let close = {
                target.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in
                    source.cancel()
                    target.cancel()
                })
            }
            if let data, !data.isEmpty {
                target.send(content: data, completion: .contentProcessed { sendError in
                    if sendError != nil || isComplete || error != nil { return close() }
                    self?.relay(from: source, to: target)
                })
            } else if isComplete || error != nil {
                close()
            } else {
                self?.relay(from: source, to: target)
            }
        }
    }

    private func refuse(_ client: NWConnection, _ status: String) {
        client.send(content: Data("HTTP/1.1 \(status)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8),
                    contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { _ in client.cancel() })
    }

    /// The host of `CONNECT host:443 HTTP/1.1`: a host name, as extensions
    /// list them, on the standard HTTPS port.
    static func host(inConnectRequest head: String) -> String? {
        let line = head.split(separator: "\r\n", maxSplits: 1).first.map(String.init) ?? ""
        let parts = line.split(separator: " ")
        guard parts.count == 3, parts[0] == "CONNECT", parts[2].hasPrefix("HTTP/1.") else { return nil }
        let authority = parts[1].lowercased()
        guard authority.hasSuffix(":443") else { return nil }
        let host = String(authority.dropLast(4))
        guard ExtensionManifest.isHostName(host) else { return nil }
        return host
    }
}
