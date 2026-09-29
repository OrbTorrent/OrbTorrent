import CryptoKit
import Foundation

/// Where extensions and what OrbTorrent knows about them are kept.
enum ExtensionPaths {
    /// `~/Library/Application Support/OrbTorrent/Extensions`
    static var root: URL { EnginePaths.support.appending(path: "Extensions", directoryHint: .isDirectory) }
    /// Extensions installed from a file or folder.
    static var installed: URL { root.appending(path: "Installed", directoryHint: .isDirectory) }
    static var checks: URL { root.appending(path: "checks.json") }
    static var settings: URL { root.appending(path: "settings.json") }
    static func storage(of name: String) -> URL { root.appending(path: "Data/\(name)/storage.json") }
    static func log(of name: String) -> URL { root.appending(path: "Logs/\(name).log") }
    /// Where `orb dev` and `orb run` reach OrbTorrent.
    static var developmentSocket: URL { EnginePaths.support.appending(path: "dev.sock") }
    /// The official extensions inside OrbTorrent.app.
    static var official: URL? { Bundle.main.resourceURL?.appending(path: "Extensions", directoryHint: .isDirectory) }
}

/// How far along a check is, for the Checks tab.
struct CheckProgress: Sendable, Equatable, Codable {
    var done: Int?
    var total: Int?
    var message: String?
}

/// A small store for each extension, kept across runs and updates.
actor ExtensionStorage {
    static let limit = 1 << 20

    private let file: URL
    private var values: [String: JSONValue]?

    init(file: URL) {
        self.file = file
    }

    private func load() -> [String: JSONValue] {
        if let values { return values }
        let loaded = (try? Data(contentsOf: file)).flatMap { try? JSONValue(data: $0) }?.object ?? [:]
        values = loaded
        return loaded
    }

    func get(_ key: String) -> JSONValue {
        load()[key] ?? .null
    }

    func keys() -> [String] {
        load().keys.sorted()
    }

    func set(_ key: String, _ value: JSONValue) throws {
        var changed = load()
        if value.isNull {
            changed[key] = nil
        } else {
            changed[key] = value
        }
        let data = JSONValue.object(changed).data()
        guard data.count <= Self.limit else {
            throw ExtensionRefusal(message: "Storage is full: an extension can keep up to 1 MB. Remove keys it no longer needs.")
        }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        values = changed
    }
}

/// Answers one run's calls: requests to the hosts it declared, the files of
/// the download it runs on, its progress and its storage.
struct ExtensionServices: ExtensionCallHandler {
    let network: ExtensionNetwork
    /// The download's files on disk by index, once they've downloaded.
    let files: [Int: URL]
    let storage: ExtensionStorage
    /// Values to hide in its logs, such as API keys.
    let secrets: [String]
    let onProgress: @Sendable (CheckProgress) -> Void
    let onLog: @Sendable (_ level: String, _ message: String) -> Void

    private var permissions: ExtensionManifest.Permissions { network.permissions }

    func handle(method: String, params: JSONValue) async throws -> JSONValue {
        switch method {
        case "fetch":
            return try await fetch(params).json
        case "files.sha256":
            let url = try file(params["file"])
            return .string(try await Self.sha256(of: url))
        case "progress":
            onProgress(CheckProgress(done: params["done"]?.int, total: params["total"]?.int,
                                     message: params["message"]?.string.map { String($0.prefix(200)) }))
            return .null
        case "storage.get":
            return await storage.get(try key(params))
        case "storage.set":
            try await storage.set(try key(params), params["value"] ?? .null)
            return .null
        case "storage.remove":
            try await storage.set(try key(params), .null)
            return .null
        case "storage.keys":
            return .array(await storage.keys().map(JSONValue.string))
        default:
            throw ExtensionRefusal(message: "OrbTorrent doesn't know “\(method)”. Update OrbTorrent, or check the @orbtorrent/api version.")
        }
    }

    func log(level: String, message: String) {
        var text = message
        for secret in secrets where secret.count >= 4 {
            text = text.replacingOccurrences(of: secret, with: "•••")
        }
        onLog(level, text)
    }

    private func key(_ params: JSONValue) throws -> String {
        guard let key = params["key"]?.string, !key.isEmpty, key.count <= 200 else {
            throw ExtensionRefusal(message: "A storage key must be text of up to 200 characters.")
        }
        return key
    }

    /// A file of the download, if the extension may read it and it's there.
    private func file(_ index: JSONValue?) throws -> URL {
        guard permissions.readsFileContents else {
            throw ExtensionRefusal(message: "Reading files isn't allowed. Add \"files\": \"contents\" to permissions in package.json.")
        }
        guard let index = index?.int else {
            throw ExtensionRefusal(message: "Pass a file from download.files.")
        }
        guard let url = files[index] else {
            throw ExtensionRefusal(message: "File \(index) isn't available: it isn't downloaded yet, or it isn't part of this download.")
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ExtensionRefusal(message: "File \(index) is missing: it was moved or deleted after downloading.")
        }
        return url
    }

    private func fetch(_ params: JSONValue) async throws -> ExtensionNetwork.Response {
        guard let text = params["url"]?.string, let url = URL(string: text) else {
            throw ExtensionRefusal(message: "fetch needs an https:// address.")
        }
        var request = ExtensionNetwork.Request(url: url)
        request.method = params["method"]?.string ?? "GET"
        for (name, value) in params["headers"]?.object ?? [:] {
            if let value = value.string { request.headers[name] = value }
        }
        switch params["body"] {
        case .string(let body)?:
            request.body = .text(body)
        case .object(let body)? where body["multipart"] != nil:
            request.body = .multipart(try (body["multipart"]?.array ?? []).map { part in
                guard let name = part["name"]?.string else {
                    throw ExtensionRefusal(message: "Each form field needs a name.")
                }
                if let index = part["file"] {
                    let file = try file(index)
                    return .file(name: name, filename: part["filename"]?.string ?? file.lastPathComponent,
                                 contentType: part["contentType"]?.string ?? "application/octet-stream", url: file)
                }
                return .field(name: name, value: part["value"]?.string ?? "")
            })
        case nil, .null?:
            break
        default:
            throw ExtensionRefusal(message: "A request body must be text, or a form from files.formData().")
        }
        return try await network.perform(request)
    }

    /// The file's SHA-256, read in pieces so large files don't fill memory.
    static func sha256(of url: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 4 << 20), !chunk.isEmpty {
                try Task.checkCancellation()
                hasher.update(data: chunk)
            }
            return hasher.finalize().hexString
        }.value
    }
}
