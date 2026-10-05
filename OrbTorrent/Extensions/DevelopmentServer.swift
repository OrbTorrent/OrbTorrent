import Darwin
import Foundation
import Observation

/// What the user decided on the install sheet `orb install` asked for.
enum InstallDecision: Sendable {
    case installed(String)
    case cancelled
    case failed(String)
}

/// Listens for `orb` (`dev`, `run`, `doctor`, `downloads` and `install`) on a socket
/// only this account can open, while development extensions are allowed.
/// Messages are JSON objects, one per line; see sdk/src/cli/connection.ts.
@MainActor
@Observable
final class DevelopmentServer {
    @ObservationIgnored private let extensions: Extensions
    /// The library's downloads, to run a hook on.
    @ObservationIgnored var torrents: () -> [Torrent] = { [] }
    /// Asks the user before loading a folder for the first time.
    @ObservationIgnored var confirmLoading: (InstalledExtension, URL) async -> Bool = { _, _ in false }
    /// Shows the install sheet, and says what the user decided.
    @ObservationIgnored var requestInstall: (URL) async -> InstallDecision = { _ in .cancelled }

    private var listener: Int32 = -1
    @ObservationIgnored private var acceptSource: DispatchSourceRead?
    @ObservationIgnored private var connections: [UUID: Connection] = [:]
    /// The extension each connected `orb dev` is watching.
    private var watching: [UUID: String] = [:]

    init(extensions: Extensions) {
        self.extensions = extensions
    }

    var isRunning: Bool { listener >= 0 }

    /// Extensions an `orb dev` is connected for, for the Develop tab.
    var watchedNames: [String] {
        Set(watching.values).sorted()
    }

    func start() {
        guard !isRunning else { return }
        let path = ExtensionPaths.developmentSocket.path
        try? FileManager.default.createDirectory(at: ExtensionPaths.developmentSocket.deletingLastPathComponent(), withIntermediateDirectories: true)
        unlink(path)
        let socket = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        guard socket >= 0 else { return }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard path.utf8.count < capacity else { close(socket); return }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in
            buffer.copyBytes(from: path.utf8)
            buffer[path.utf8.count] = 0
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(socket, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(path, 0o600) == 0, listen(socket, 8) == 0 else {
            close(socket)
            unlink(path)
            return
        }
        _ = fcntl(socket, F_SETFL, fcntl(socket, F_GETFL) | O_NONBLOCK)
        listener = socket
        let source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.accept() }
        }
        source.resume()
        acceptSource = source
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil
        if listener >= 0 {
            close(listener)
            listener = -1
        }
        unlink(ExtensionPaths.developmentSocket.path)
        for connection in connections.values { connection.close() }
        connections.removeAll()
        watching.removeAll()
    }

    private func accept() {
        let client = Darwin.accept(listener, nil, nil)
        guard client >= 0 else { return }
        // Only this account's programs.
        var uid: uid_t = 0
        var gid: gid_t = 0
        guard getpeereid(client, &uid, &gid) == 0, uid == getuid() else {
            close(client)
            return
        }
        // Reads wait for data to arrive; writes block until sent.
        _ = fcntl(client, F_SETFL, fcntl(client, F_GETFL) & ~O_NONBLOCK)
        let id = UUID()
        let connection = Connection(socket: client) { [weak self] message, connection in
            self?.handle(message, from: connection)
        } onClose: { [weak self] connection in
            self?.closed(connection, id: id)
        }
        connections[id] = connection
    }

    private func closed(_ connection: Connection, id: UUID) {
        connections[id] = nil
        watching[id] = nil
        for listener in connection.listeners { extensions.stopListening(listener) }
        for listener in connection.logListeners { extensions.logs.stopListening(listener) }
    }

    // MARK: Messages

    private func handle(_ message: JSONValue, from connection: Connection) {
        switch message["type"]?.string {
        case "hello":
            connection.send(["type": "hello", "app": "OrbTorrent",
                             "version": .string(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""),
                             "api": .string(ExtensionAPI.versionString)])
        case "load":
            Task { await load(message["path"]?.string, for: connection) }
        case "watch":
            if let name = message["name"]?.string { watch(name, for: connection) }
        case "run":
            Task { await run(message, for: connection) }
        case "downloads":
            connection.send(["type": "downloads", "downloads": .array(torrents().map { torrent in
                ["id": .string(torrent.hash), "name": .string(torrent.name), "size": .number(Double(torrent.size)),
                 "progress": .number(torrent.progress), "finished": .bool(torrent.isComplete)]
            })])
        case "status":
            status(message, for: connection)
        case "install":
            Task { await install(message["path"]?.string, for: connection) }
        default:
            connection.send(["type": "error", "message": "OrbTorrent doesn't know that request. Update OrbTorrent or @orbtorrent/api."])
        }
    }

    private func load(_ path: String?, for connection: Connection) async {
        guard let path else { return connection.fail("No folder was given.") }
        let folder = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
        do {
            let item = try InstalledExtension.load(from: folder, source: .development)
            if !extensions.registry.isKnownDevelopmentFolder(folder) {
                guard await confirmLoading(item, folder) else {
                    return connection.fail("You chose not to load it in OrbTorrent.")
                }
            }
            let loaded = try extensions.registry.loadDevelopment(from: folder)
            connection.send(["type": "loaded", "name": .string(loaded.name), "title": .string(loaded.title),
                             "replacesOfficial": .bool(loaded.replacesOfficial)])
        } catch let invalid as ExtensionManifest.Invalid {
            connection.send(["type": "error", "message": "OrbTorrent couldn't load it.", "details": .array(invalid.problems.map(JSONValue.string))])
        } catch {
            connection.fail("OrbTorrent couldn't load it: \(error.localizedDescription)")
        }
    }

    /// Streams an extension's logs and results to `orb dev`.
    private func watch(_ name: String, for connection: Connection) {
        if let id = connections.first(where: { $0.value === connection })?.key { watching[id] = name }
        connection.logListeners.append(extensions.logs.listen { [weak connection] logged, entry in
            guard logged == name else { return }
            connection?.send(Self.log(entry, name: name))
        })
        connection.listeners.append(extensions.listen { [weak connection] event in
            guard let message = Self.message(for: event), message["name"]?.string == name else { return }
            connection?.send(message)
        })
    }

    private func run(_ message: JSONValue, for connection: Connection) async {
        guard let name = message["name"]?.string, let item = extensions.registry.named(name) else {
            return connection.fail("OrbTorrent has no extension named “\(message["name"]?.string ?? "")”.")
        }
        guard let hook = item.manifest.hooks.first(where: { $0.name == message["hook"]?.string }) else {
            return connection.fail("“\(item.title)” has no hook named “\(message["hook"]?.string ?? "")”.")
        }
        let query = (message["download"]?.string ?? "").trimmingCharacters(in: .whitespaces)
        let library = torrents()
        let matches = library.filter { $0.hash.lowercased() == query.lowercased() }.isEmpty
            ? library.filter { $0.name.localizedCaseInsensitiveContains(query) }
            : library.filter { $0.hash.lowercased() == query.lowercased() }
        guard !query.isEmpty, let torrent = matches.first else {
            let names = library.prefix(8).map { JSONValue.string("\($0.name) (\($0.hash))") }
            return connection.send(["type": "error", "message": "No download matches “\(query)”. Your downloads:", "details": .array(names)])
        }
        guard matches.count == 1 else {
            return connection.send(["type": "error", "message": "“\(query)” matches \(matches.count) downloads. Use one of these names or info hashes:",
                                    "details": .array(matches.prefix(8).map { .string("\($0.name) (\($0.hash))") })])
        }
        if !extensions.canRun(hook, on: torrent) {
            return connection.fail(hook.event == .afterChecks
                ? "“\(torrent.name)” hasn't finished, and no check is holding it, so there's nothing to report yet. Choose a finished or held download."
                : "“\(torrent.name)” hasn't finished downloading, so its files aren't all there. Choose a finished download.")
        }

        // Stream this run's logs and progress while it runs.
        let logListener = extensions.logs.listen { [weak connection] logged, entry in
            guard logged == name, entry.download == torrent.name else { return }
            connection?.send(Self.log(entry, name: name))
        }
        let eventListener = extensions.listen { [weak connection] event in
            if case .progress(let eventName, let hash, _, _, _) = event, eventName == name, hash == torrent.hash,
               let message = Self.message(for: event) {
                connection?.send(message)
            }
        }
        defer {
            extensions.logs.stopListening(logListener)
            extensions.stopListening(eventListener)
        }
        guard let record = await extensions.runAgain(item, hook, on: torrent) else {
            return connection.fail("OrbTorrent couldn't read the download's files from the engine.")
        }
        var result: [String: JSONValue] = [
            "type": "result", "hook": .string(hook.name),
            "download": ["id": .string(torrent.hash), "name": .string(torrent.name)],
            "outcome": .string(record.status == .didNotFinish ? "didNotFinish" : "returned"),
            "status": .string(record.status.rawValue), "summary": .string(record.summary), "message": .string(record.summary),
        ]
        if let details = record.details { result["details"] = .string(details) }
        if let link = record.link { result["link"] = ["title": .string(link.title), "url": .string(link.url.absoluteString)] }
        if let files = record.files {
            result["files"] = .array(files.map { file in
                var entry: [String: JSONValue] = ["index": .number(Double(file.index)), "path": .string(file.path),
                                                  "status": .string(file.status.rawValue)]
                if let summary = file.summary { entry["summary"] = .string(summary) }
                return .object(entry)
            })
        }
        connection.send(.object(result))
    }

    /// For `orb install`: the install sheet, where only the user can say yes.
    private func install(_ path: String?, for connection: Connection) async {
        guard let path else { return connection.fail("No file was given.") }
        switch await requestInstall(URL(fileURLWithPath: path)) {
        case .installed(let name):
            connection.send(["type": "installed", "name": .string(name)])
        case .cancelled:
            connection.fail("The user chose not to install it.")
        case .failed(let message):
            connection.fail("OrbTorrent couldn't install it: \(message)")
        }
    }

    /// For `orb doctor`: whether a built folder has been allowed, and which
    /// copy of the extension OrbTorrent runs, if any.
    private func status(_ message: JSONValue, for connection: Connection) {
        let registry = extensions.registry
        let name = message["name"]?.string ?? ""
        var reply: [String: JSONValue] = ["type": "status", "api": .string(ExtensionAPI.versionString)]
        if let path = message["path"]?.string {
            let folder = URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
            reply["allowed"] = .bool(registry.isKnownDevelopmentFolder(folder))
        }
        if let item = registry.named(name) {
            reply["active"] = ["source": .string(item.source.rawValue), "version": .string(item.manifest.version ?? ""),
                               "on": .bool(registry.isEnabled(item))]
        }
        if let item = registry.installed(named: name) {
            reply["installed"] = ["version": .string(item.manifest.version ?? "")]
        }
        connection.send(.object(reply))
    }

    private static func log(_ entry: ExtensionLogEntry, name: String) -> JSONValue {
        var message: [String: JSONValue] = ["type": "log", "name": .string(name), "level": .string(entry.level), "message": .string(entry.message)]
        if let entryPoint = entry.entryPoint { message["hook"] = .string(entryPoint) }
        if let download = entry.download { message["download"] = ["name": .string(download)] }
        return .object(message)
    }

    private static func message(for event: Extensions.Event) -> JSONValue? {
        switch event {
        case .check(let name, let hash, let download, let record):
            guard record.status.isFinished else { return nil }
            return ["type": "check", "name": .string(name), "hook": .string(record.hookName),
                    "download": ["id": .string(hash), "name": .string(download)],
                    "status": .string(record.status.rawValue), "summary": .string(record.summary)]
        case .progress(let name, let hash, let download, let hook, let progress):
            var message: [String: JSONValue] = ["type": "progress", "name": .string(name), "hook": .string(hook),
                                                "download": ["id": .string(hash), "name": .string(download)]]
            if let done = progress.done { message["done"] = .number(Double(done)) }
            if let total = progress.total { message["total"] = .number(Double(total)) }
            if let text = progress.message { message["message"] = .string(text) }
            return .object(message)
        }
    }
}

/// One `orb` connection.
@MainActor
private final class Connection {
    private let socket: Int32
    private var source: DispatchSourceRead?
    private var buffer = Data()
    private let onMessage: (JSONValue, Connection) -> Void
    private let onClose: (Connection) -> Void
    private var isClosed = false
    var listeners: [UUID] = []
    var logListeners: [UUID] = []

    init(socket: Int32, onMessage: @escaping (JSONValue, Connection) -> Void, onClose: @escaping (Connection) -> Void) {
        self.socket = socket
        self.onMessage = onMessage
        self.onClose = onClose
        var noSignal: Int32 = 1
        setsockopt(socket, SOL_SOCKET, SO_NOSIGPIPE, &noSignal, socklen_t(MemoryLayout<Int32>.size))
        let source = DispatchSource.makeReadSource(fileDescriptor: socket, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.read() }
        }
        source.resume()
        self.source = source
    }

    private func read() {
        var chunk = [UInt8](repeating: 0, count: 65_536)
        let count = Darwin.read(socket, &chunk, chunk.count)
        guard count > 0 else { return close() }
        buffer.append(contentsOf: chunk[0..<count])
        if buffer.count > 4 << 20 { return close() }
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            if let message = try? JSONValue(data: Data(line)) { onMessage(message, self) }
        }
    }

    func send(_ message: JSONValue) {
        guard !isClosed else { return }
        var data = message.data()
        data.append(0x0A)
        let written = data.withUnsafeBytes { Darwin.write(socket, $0.baseAddress, $0.count) }
        if written < 0 { close() }
    }

    func fail(_ message: String) {
        send(["type": "error", "message": .string(message)])
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        source?.cancel()
        source = nil
        Darwin.close(socket)
        onClose(self)
    }
}
