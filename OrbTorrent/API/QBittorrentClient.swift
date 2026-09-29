import Foundation

/// A client for the bundled engine's qBittorrent Web API (v2), reached only
/// over the loopback interface.
actor QBittorrentClient {
    struct Endpoint: Sendable, Equatable {
        let port: Int
        let username: String
        let password: String
    }

    struct AddOptions: Sendable {
        var savePath: String?
        var startImmediately = true
        var sequentialDownload = false
        var firstAndLastPiecesFirst = false
        /// Stops the torrent once its file list is known, before any data
        /// downloads, so its checks can run first.
        var stopsWhenFilesAreKnown = false
    }

    private enum Body {
        case none
        case form([(String, String)])
        case multipart(MultipartForm)
    }

    private var endpoint: Endpoint
    private var sessionCookie: String?
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(endpoint: Endpoint) {
        self.endpoint = endpoint
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.timeoutIntervalForRequest = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.connectionProxyDictionary = [:]
        session = URLSession(configuration: configuration)
    }

    func update(endpoint: Endpoint) {
        guard endpoint != self.endpoint else { return }
        self.endpoint = endpoint
        sessionCookie = nil
    }

    // MARK: Session

    func login() async throws {
        let (data, response) = try await send(
            "auth/login",
            body: .form([("username", endpoint.username), ("password", endpoint.password)]),
            authenticate: false
        )
        let text = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(response.statusCode), text != "Fails." else {
            throw APIError.unauthorized
        }
        if let header = response.value(forHTTPHeaderField: "Set-Cookie"),
           let pair = header.split(separator: ";").first {
            sessionCookie = String(pair).trimmingCharacters(in: .whitespaces)
        }
    }

    func appVersion() async throws -> String {
        try await text("app/version")
    }

    func buildInfo() async throws -> BuildInfo {
        try await decode("app/buildInfo")
    }

    func preferences() async throws -> EnginePreferences {
        try await decode("app/preferences")
    }

    func setPreferences(_ values: [String: PreferenceValue]) async throws {
        let json = try JSONEncoder().encode(values)
        try await post("app/setPreferences", [("json", String(decoding: json, as: UTF8.self))])
    }

    /// Asks the engine to save its state and exit.
    func shutdown() async throws {
        try await post("app/shutdown", [])
    }

    // MARK: Reading

    func transferInfo() async throws -> TransferInfo {
        try await decode("transfer/info")
    }

    func torrents() async throws -> [Torrent] {
        try await decode("torrents/info")
    }

    func files(of hash: String) async throws -> [TorrentFile] {
        try await decode("torrents/files", query: ["hash": hash])
    }

    func properties(of hash: String) async throws -> TorrentProperties {
        try await decode("torrents/properties", query: ["hash": hash])
    }

    func trackers(of hash: String) async throws -> [Tracker] {
        try await decode("torrents/trackers", query: ["hash": hash])
    }

    func peers(of hash: String) async throws -> [Peer] {
        let snapshot: PeersSnapshot = try await decode("sync/torrentPeers", query: ["hash": hash, "rid": "0"])
        return snapshot.peers.values.sorted { lhs, rhs in
            if lhs.downloadSpeed != rhs.downloadSpeed { return lhs.downloadSpeed > rhs.downloadSpeed }
            return lhs.ip < rhs.ip
        }
    }

    // MARK: Adding

    func add(magnetOrURL link: String, options: AddOptions) async throws {
        var form = MultipartForm()
        form.add("urls", link)
        apply(options, to: &form)
        try await submitAdd(form)
    }

    func add(torrentFile data: Data, filename: String, options: AddOptions) async throws {
        var form = MultipartForm()
        form.addFile("torrents", filename: filename, contentType: "application/x-bittorrent", data: data)
        apply(options, to: &form)
        try await submitAdd(form)
    }

    /// A magnet link's name and files, which the engine asks the link's peers
    /// for. Nil until they've sent them: ask again until then, which doesn't
    /// start another search. Adding the link afterwards uses what they sent.
    /// The engine keeps what they sent for this login only, so signing in again
    /// means asking again.
    func metadata(ofMagnet link: String) async throws -> TorrentMetadata? {
        // The engine decodes the link once more than the form needs.
        let (data, response) = try await send("torrents/fetchMetadata", body: .form([("source", Self.formEncode(link))]))
        try check(response, data)
        guard response.statusCode == 200 else { return nil }
        do {
            return try decoder.decode(FetchedMetadata.self, from: data).metadata
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func apply(_ options: AddOptions, to form: inout MultipartForm) {
        if let savePath = options.savePath { form.add("savepath", savePath) }
        let stopped = options.startImmediately ? "false" : "true"
        form.add("stopped", stopped)
        form.add("paused", stopped) // qBittorrent 4.x name
        form.add("sequentialDownload", options.sequentialDownload ? "true" : "false")
        form.add("firstLastPiecePrio", options.firstAndLastPiecesFirst ? "true" : "false")
        if options.stopsWhenFilesAreKnown { form.add("stopCondition", "MetadataReceived") }
    }

    private func submitAdd(_ form: MultipartForm) async throws {
        let (data, response) = try await send("torrents/add", body: .multipart(form))
        let text = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(response.statusCode), text != "Fails." else {
            throw APIError.rejected("The engine couldn't add this torrent. It may be invalid or already added.")
        }
    }

    // MARK: Controlling

    func start(_ hashes: [String]) async throws {
        try await postWithFallback("torrents/start", legacy: "torrents/resume", hashes)
    }

    func stop(_ hashes: [String]) async throws {
        try await postWithFallback("torrents/stop", legacy: "torrents/pause", hashes)
    }

    func forceStart(_ hashes: [String]) async throws {
        try await post("torrents/setForceStart", [("hashes", joined(hashes)), ("value", "true")])
    }

    func delete(_ hashes: [String], deleteFiles: Bool) async throws {
        try await post("torrents/delete", [("hashes", joined(hashes)), ("deleteFiles", deleteFiles ? "true" : "false")])
    }

    func recheck(_ hashes: [String]) async throws {
        try await post("torrents/recheck", [("hashes", joined(hashes))])
    }

    func reannounce(_ hashes: [String]) async throws {
        try await post("torrents/reannounce", [("hashes", joined(hashes))])
    }

    func toggleSequentialDownload(_ hashes: [String]) async throws {
        try await post("torrents/toggleSequentialDownload", [("hashes", joined(hashes))])
    }

    func toggleFirstLastPiecePriority(_ hashes: [String]) async throws {
        try await post("torrents/toggleFirstLastPiecePrio", [("hashes", joined(hashes))])
    }

    func setFilePriority(_ priority: FilePriority, files indices: [Int], in hash: String) async throws {
        guard !indices.isEmpty else { return }
        try await post("torrents/filePrio", [
            ("hash", hash),
            ("id", indices.map(String.init).joined(separator: "|")),
            ("priority", String(priority.rawValue)),
        ])
    }

    func setLocation(_ hashes: [String], to path: String) async throws {
        try await post("torrents/setLocation", [("hashes", joined(hashes)), ("location", path)])
    }

    /// Adds trackers to a torrent, each in a tier of its own from `firstTier`
    /// on, so the engine announces to every one of them.
    func addTrackers(_ urls: [String], to hash: String, firstTier: Int) async throws {
        guard !urls.isEmpty else { return }
        // The engine starts at tier 0 and moves to the next tier at each blank line.
        let tiers = String(repeating: "\n", count: max(firstTier, 0)) + urls.joined(separator: "\n\n")
        try await post("torrents/addTrackers", [("hash", hash), ("urls", tiers)])
    }

    func removeTrackers(_ urls: [String], from hash: String) async throws {
        guard !urls.isEmpty else { return }
        // The engine decodes each address once more than the form needs.
        try await post("torrents/removeTrackers", [("hash", hash), ("urls", urls.map(Self.formEncode).joined(separator: "|"))])
    }

    // MARK: Transport

    private func joined(_ hashes: [String]) -> String {
        hashes.isEmpty ? "all" : hashes.joined(separator: "|")
    }

    private func postWithFallback(_ path: String, legacy: String, _ hashes: [String]) async throws {
        do {
            try await post(path, [("hashes", joined(hashes))])
        } catch APIError.http(let status, _) where status == 404 {
            try await post(legacy, [("hashes", joined(hashes))])
        }
    }

    private func post(_ path: String, _ fields: [(String, String)]) async throws {
        let (data, response) = try await send(path, body: .form(fields))
        try check(response, data)
    }

    private func text(_ path: String) async throws -> String {
        let (data, response) = try await send(path)
        try check(response, data)
        return String(decoding: data, as: UTF8.self)
    }

    private func decode<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        let (data, response) = try await send(path, query: query)
        try check(response, data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(String(describing: error))
        }
    }

    private func check(_ response: HTTPURLResponse, _ data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw APIError.http(status: response.statusCode, body: String(decoding: data, as: UTF8.self))
        }
    }

    private func send(_ path: String,
                      query: [String: String] = [:],
                      body: Body = .none,
                      authenticate: Bool = true) async throws -> (Data, HTTPURLResponse) {
        if authenticate, sessionCookie == nil {
            try await login()
        }
        let result = try await perform(path, query: query, body: body)
        guard authenticate, result.1.statusCode == 403 else { return result }
        // The session expired (for example after an engine restart): sign in again once.
        sessionCookie = nil
        try await login()
        return try await perform(path, query: query, body: body)
    }

    private func perform(_ path: String, query: [String: String], body: Body) async throws -> (Data, HTTPURLResponse) {
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = endpoint.port
        components.path = "/api/v2/" + path
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidResponse }

        var request = URLRequest(url: url)
        if let sessionCookie {
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        }
        switch body {
        case .none:
            request.httpMethod = "GET"
        case .form(let fields):
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(fields.map { "\(Self.formEncode($0.0))=\(Self.formEncode($0.1))" }
                .joined(separator: "&").utf8)
        case .multipart(let form):
            request.httpMethod = "POST"
            request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
            request.httpBody = form.finalized()
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .networkConnectionLost, .timedOut, .cannotFindHost, .notConnectedToInternet:
                throw APIError.unreachable
            default:
                throw error
            }
        }
    }

    private static let formAllowed: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    private static func formEncode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? value
    }
}
