import Darwin
import Foundation

/// A request an extension can't make, with what to do about it.
struct ExtensionRefusal: LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

/// Makes an extension's HTTPS requests, only to the hosts it declared and
/// never to this Mac or the local network.
struct ExtensionNetwork: Sendable {
    struct Request: Sendable {
        var url: URL
        var method = "GET"
        var headers: [String: String] = [:]
        var body: Body = .none
    }

    enum Body: Sendable {
        case none
        case text(String)
        /// A multipart form, streamed from disk so files of any size can be uploaded.
        case multipart([Part])
    }

    enum Part: Sendable {
        case field(name: String, value: String)
        case file(name: String, filename: String, contentType: String, url: URL)
    }

    struct Response: Sendable, Equatable {
        let status: Int
        let headers: [String: String]
        let body: String
        let url: String

        var json: JSONValue {
            ["status": .number(Double(status)), "headers": .object(headers.mapValues(JSONValue.string)),
             "body": .string(body), "url": .string(url)]
        }
    }

    let extensionName: String
    let permissions: ExtensionManifest.Permissions
    /// Looks up a host's addresses; replaced in tests.
    var resolve: @Sendable (String) async -> [String] = { await ExtensionNetwork.addresses(of: $0) }

    static let maximumResponse = 10 << 20
    static let timeout: TimeInterval = 30
    private static let droppedHeaders: Set<String> = ["host", "content-length", "connection", "transfer-encoding", "cookie"]
    private static let methods: Set<String> = ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE"]

    /// Why the extension can't reach this URL, if it can't.
    func refusal(for url: URL) -> ExtensionRefusal? {
        guard url.scheme?.lowercased() == "https" else {
            return ExtensionRefusal(message: "Request to \(url.absoluteString) was refused: extensions can only use https:// addresses.")
        }
        guard let host = url.host()?.lowercased(), !host.isEmpty else {
            return ExtensionRefusal(message: "Request to \(url.absoluteString) was refused: the address has no host.")
        }
        guard url.user() == nil, url.password() == nil else {
            return ExtensionRefusal(message: "Request to \(url.absoluteString) was refused: put credentials in a header, not the address.")
        }
        guard permissions.allows(host: host) else {
            return ExtensionRefusal(message: "Request to \(host) was refused. Add \"\(host)\" to permissions.network in package.json.")
        }
        if let port = url.port, port != 443 {
            return ExtensionRefusal(message: "Request to \(host):\(port) was refused: extensions can only use the standard HTTPS port.")
        }
        return nil
    }

    func perform(_ request: Request) async throws -> Response {
        let method = request.method.uppercased()
        guard Self.methods.contains(method) else {
            throw ExtensionRefusal(message: "The request method “\(request.method)” isn't supported.")
        }
        if let refusal = refusal(for: request.url) { throw refusal }
        let host = request.url.host()!.lowercased()
        let addresses = await resolve(host)
        guard !addresses.isEmpty else {
            throw ExtensionRefusal(message: "\(host) couldn't be found. Check the address and your connection.")
        }
        if let local = addresses.first(where: { !NetworkAddress.isPublic($0) }) {
            throw ExtensionRefusal(message: "Request to \(host) was refused: it points to \(local), which is on this Mac or your local network.")
        }

        var urlRequest = URLRequest(url: request.url, timeoutInterval: Self.timeout)
        urlRequest.httpMethod = method
        for (name, value) in request.headers where !Self.droppedHeaders.contains(name.lowercased()) {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        urlRequest.setValue("OrbTorrent-Extension/\(extensionName)", forHTTPHeaderField: "User-Agent")

        let session = URLSession(configuration: Self.configuration, delegate: RedirectGuard(network: self), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        switch request.body {
        case .none:
            return try await receive(session.bytes(for: urlRequest))
        case .text(let text):
            urlRequest.httpBody = Data(text.utf8)
            return try await receive(session.bytes(for: urlRequest))
        case .multipart(let parts):
            let boundary = "OrbTorrent-\(UUID().uuidString)"
            urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            let form = try await Task.detached { try Self.writeMultipart(parts, boundary: boundary) }.value
            defer { try? FileManager.default.removeItem(at: form) }
            let (data, response) = try await session.upload(for: urlRequest, fromFile: form)
            guard data.count <= Self.maximumResponse else { throw Self.tooLarge }
            return Self.response(data, response)
        }
    }

    private func receive(_ result: (URLSession.AsyncBytes, URLResponse)) async throws -> Response {
        let (bytes, response) = result
        var data = Data()
        if response.expectedContentLength > Self.maximumResponse { throw Self.tooLarge }
        for try await byte in bytes {
            data.append(byte)
            if data.count > Self.maximumResponse { throw Self.tooLarge }
        }
        return Self.response(data, response)
    }

    private static let tooLarge = ExtensionRefusal(message: "The response was larger than 10 MB, the most an extension can receive.")

    private static func response(_ data: Data, _ response: URLResponse) -> Response {
        let http = response as? HTTPURLResponse
        var headers: [String: String] = [:]
        for (name, value) in http?.allHeaderFields ?? [:] {
            headers[String(describing: name).lowercased()] = String(describing: value)
        }
        return Response(status: http?.statusCode ?? 0, headers: headers,
                        body: String(decoding: data, as: UTF8.self), url: response.url?.absoluteString ?? "")
    }

    private static var configuration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = timeout
        return configuration
    }

    /// Writes a multipart form to a temporary file, copying files in pieces.
    private static func writeMultipart(_ parts: [Part], boundary: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-upload-\(UUID().uuidString)")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let output = try FileHandle(forWritingTo: url)
        defer { try? output.close() }
        func write(_ text: String) throws { try output.write(contentsOf: Data(text.utf8)) }
        for part in parts {
            try write("--\(boundary)\r\n")
            switch part {
            case .field(let name, let value):
                try write("Content-Disposition: form-data; name=\"\(quoted(name))\"\r\n\r\n\(value)\r\n")
            case .file(let name, let filename, let contentType, let file):
                try write("Content-Disposition: form-data; name=\"\(quoted(name))\"; filename=\"\(quoted(filename))\"\r\n")
                try write("Content-Type: \(contentType)\r\n\r\n")
                let input = try FileHandle(forReadingFrom: file)
                defer { try? input.close() }
                while let chunk = try input.read(upToCount: 4 << 20), !chunk.isEmpty {
                    try output.write(contentsOf: chunk)
                }
                try write("\r\n")
            }
        }
        try write("--\(boundary)--\r\n")
        return url
    }

    private static func quoted(_ text: String) -> String {
        text.replacingOccurrences(of: "\"", with: "%22").replacingOccurrences(of: "\r", with: "").replacingOccurrences(of: "\n", with: "")
    }

    /// The host's IPv4 and IPv6 addresses.
    static func addresses(of host: String) async -> [String] {
        await Task.detached {
            var hints = addrinfo()
            hints.ai_socktype = SOCK_STREAM
            var list: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(host, "443", &hints, &list) == 0, let first = list else { return [] }
            defer { freeaddrinfo(list) }
            var addresses: [String] = []
            for entry in sequence(first: first, next: { $0.pointee.ai_next }) {
                var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(entry.pointee.ai_addr, entry.pointee.ai_addrlen, &buffer, socklen_t(buffer.count),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let length = buffer.firstIndex(of: 0) ?? buffer.count
                    addresses.append(String(decoding: buffer[..<length].map { UInt8(bitPattern: $0) }, as: UTF8.self))
                }
            }
            return addresses
        }.value
    }
}

/// Follows a redirect only to an address the extension may reach.
private final class RedirectGuard: NSObject, URLSessionTaskDelegate, Sendable {
    let network: ExtensionNetwork

    init(network: ExtensionNetwork) {
        self.network = network
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        // Declining hands the redirect itself to the extension.
        guard let url = request.url, network.refusal(for: url) == nil else { return nil }
        return request
    }
}

/// Which IP addresses are on the internet, rather than this Mac or a local network.
enum NetworkAddress {
    static func isPublic(_ address: String) -> Bool {
        let text = address.split(separator: "%").first.map(String.init) ?? address
        var v4 = in_addr()
        if inet_pton(AF_INET, text, &v4) == 1 {
            return isPublic(ipv4: UInt32(bigEndian: v4.s_addr))
        }
        var v6 = in6_addr()
        guard inet_pton(AF_INET6, text, &v6) == 1 else { return false }
        let bytes = withUnsafeBytes(of: v6) { Array($0) }
        // IPv4-mapped (::ffff:a.b.c.d) and NAT64 (64:ff9b::a.b.c.d) addresses carry an IPv4 one.
        if bytes[0..<10].allSatisfy({ $0 == 0 }) && bytes[10] == 0xFF && bytes[11] == 0xFF
            || bytes[0..<12] == [0x00, 0x64, 0xFF, 0x9B, 0, 0, 0, 0, 0, 0, 0, 0] {
            let embedded = bytes[12..<16].reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
            return isPublic(ipv4: embedded)
        }
        // Only global unicast, 2000::/3, and not the documentation range 2001:db8::/32.
        guard bytes[0] & 0xE0 == 0x20 else { return false }
        return !(bytes[0] == 0x20 && bytes[1] == 0x01 && bytes[2] == 0x0D && bytes[3] == 0xB8)
    }

    private static func isPublic(ipv4 address: UInt32) -> Bool {
        let blocked: [(UInt32, Int)] = [
            (0x00000000, 8), (0x0A000000, 8), (0x64400000, 10), (0x7F000000, 8), (0xA9FE0000, 16),
            (0xAC100000, 12), (0xC0000000, 24), (0xC0000200, 24), (0xC0A80000, 16), (0xC6120000, 15),
            (0xC6336400, 24), (0xCB007100, 24), (0xE0000000, 4), (0xF0000000, 4),
        ]
        return !blocked.contains { network, bits in
            let mask: UInt32 = bits == 0 ? 0 : ~UInt32(0) << (32 - UInt32(bits))
            return address & mask == network
        }
    }
}
