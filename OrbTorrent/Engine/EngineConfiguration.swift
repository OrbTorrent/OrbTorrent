import CommonCrypto
import Foundation
import Security

/// Writes the few settings the engine needs before it can be reached:
/// accepting the legal notice and enabling the Web API on 127.0.0.1 with
/// OrbTorrent's private login. Everything else is configured over the API.
enum EngineConfiguration {
    /// - Parameter networkInterface: the only interface the engine may use,
    ///   or empty for any, set before it starts so it never starts on another.
    static func prepare(for credentials: EngineCredentials, networkInterface: String = "") throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: EnginePaths.configFile.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        var ini = IniFile(contents: (try? String(contentsOf: EnginePaths.configFile, encoding: .utf8)) ?? "")
        ini.set("Accepted", "true", in: "LegalNotice")
        ini.set("WebUI\\Enabled", "true", in: "Preferences")
        ini.set("WebUI\\Address", "127.0.0.1", in: "Preferences")
        ini.set("WebUI\\Port", String(credentials.port), in: "Preferences")
        ini.set("WebUI\\Username", credentials.username, in: "Preferences")
        ini.set("WebUI\\Password_PBKDF2", "\"\(passwordHash(credentials.password))\"", in: "Preferences")
        ini.set("WebUI\\LocalHostAuth", "true", in: "Preferences")
        ini.set("WebUI\\UseUPnP", "false", in: "Preferences")
        ini.set("WebUI\\AlternativeUIEnabled", "false", in: "Preferences")
        ini.set("WebUI\\CSRFProtection", "true", in: "Preferences")
        ini.set("WebUI\\HostHeaderValidation", "true", in: "Preferences")
        ini.set("WebUI\\ServerDomains", "127.0.0.1;localhost", in: "Preferences")
        // OrbTorrent doesn't show peers' countries, so the engine needn't
        // download a country database for them each month.
        ini.set("Connection\\ResolvePeerCountries", "false", in: "Preferences")
        ini.set("Session\\Interface", networkInterface, in: "BitTorrent")
        ini.set("Session\\InterfaceName", networkInterface, in: "BitTorrent")
        try ini.contents.write(to: EnginePaths.configFile, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: EnginePaths.configFile.path)
    }

    /// qBittorrent's password format: PBKDF2-HMAC-SHA512, 100 000 rounds,
    /// 16-byte salt, 64-byte key, stored as `@ByteArray(salt:key)` in Base64.
    static func passwordHash(_ password: String) -> String {
        var salt = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, salt.count, &salt)
        var key = [UInt8](repeating: 0, count: 64)
        let passwordBytes = Array(password.utf8)
        passwordBytes.withUnsafeBufferPointer { passwordBuffer in
            passwordBuffer.withMemoryRebound(to: CChar.self) { passwordChars in
                _ = CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordChars.baseAddress, passwordChars.count,
                    salt, salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                    100_000,
                    &key, key.count
                )
            }
        }
        return "@ByteArray(\(Data(salt).base64EncodedString()):\(Data(key).base64EncodedString()))"
    }
}

/// A minimal, order-preserving editor for Qt's INI settings files.
struct IniFile {
    private var lines: [String]

    init(contents: String) {
        lines = contents.isEmpty ? [] : contents.components(separatedBy: "\n")
        while lines.last?.isEmpty == true { lines.removeLast() }
    }

    var contents: String { lines.joined(separator: "\n") + "\n" }

    /// A value as Qt writes it, without the quotes it puts around some.
    func value(_ key: String, in section: String) -> String? {
        guard let start = lines.firstIndex(of: "[\(section)]") else { return nil }
        for line in lines[(start + 1)...] {
            if line.hasPrefix("[") { break }
            guard line.hasPrefix("\(key)=") else { continue }
            let value = String(line.dropFirst(key.count + 1))
            guard value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") else { return value }
            return String(value.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        return nil
    }

    mutating func set(_ key: String, _ value: String, in section: String) {
        let header = "[\(section)]"
        guard let start = lines.firstIndex(of: header) else {
            if !lines.isEmpty { lines.append("") }
            lines.append(header)
            lines.append("\(key)=\(value)")
            return
        }
        var end = lines.count
        for index in (start + 1)..<lines.count where lines[index].hasPrefix("[") {
            end = index
            break
        }
        if let existing = (start + 1..<end).first(where: { lines[$0].hasPrefix("\(key)=") }) {
            lines[existing] = "\(key)=\(value)"
        } else {
            var insertAt = end
            while insertAt > start + 1, lines[insertAt - 1].isEmpty { insertAt -= 1 }
            lines.insert("\(key)=\(value)", at: insertAt)
        }
    }
}
