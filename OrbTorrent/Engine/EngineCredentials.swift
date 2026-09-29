import Darwin
import Foundation
import Security

/// The random login OrbTorrent uses for its private engine. It is stored in a file
/// readable only by the current user and never leaves the Mac: the engine only
/// listens on 127.0.0.1.
struct EngineCredentials: Codable, Sendable, Equatable {
    var port: Int
    var username: String
    var password: String

    var endpoint: QBittorrentClient.Endpoint {
        .init(port: port, username: username, password: password)
    }

    /// The saved credentials, without creating or changing anything.
    static func loadSaved() -> EngineCredentials? {
        guard let data = try? Data(contentsOf: EnginePaths.credentials) else { return nil }
        return try? JSONDecoder().decode(EngineCredentials.self, from: data)
    }

    /// Loads the saved credentials, creating them on first launch and moving to
    /// a new port if the saved one has been taken by another program.
    static func loadOrCreate() throws -> EngineCredentials {
        var credentials: EngineCredentials
        if let saved = loadSaved() {
            credentials = saved
        } else {
            credentials = EngineCredentials(port: 0, username: "orbtorrent", password: randomPassword())
        }
        if credentials.port == 0 || !isPortFree(credentials.port) {
            credentials.port = findFreePort()
        }
        try credentials.save()
        return credentials
    }

    func save() throws {
        try FileManager.default.createDirectory(at: EnginePaths.support, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(self)
        try data.write(to: EnginePaths.credentials, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: EnginePaths.credentials.path)
    }

    private static func randomPassword() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Picks a free port in the dynamic range.
    private static func findFreePort() -> Int {
        for _ in 0..<50 {
            let candidate = Int.random(in: 49_152...65_000)
            if isPortFree(candidate) { return candidate }
        }
        return 58_080
    }

    static func isPortFree(_ port: Int) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD >= 0 else { return false }
        defer { close(socketFD) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(UInt16(port).bigEndian)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        return result == 0
    }
}
