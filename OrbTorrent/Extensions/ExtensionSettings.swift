import Foundation
import Observation
import Security

/// Where extensions' passwords, such as API keys, are kept.
protocol SecretStore: Sendable {
    func read(service: String, account: String) -> String?
    func write(_ value: String, service: String, account: String) throws
    func delete(service: String, account: String)
}

/// The login Keychain.
struct KeychainSecrets: SecretStore {
    struct Failure: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "error \(status)"
            return "The Keychain couldn't save it: \(message)"
        }
    }

    private func query(_ service: String, _ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    func read(service: String, account: String) -> String? {
        var query = query(service, account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(service, account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query(service, account)
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = "OrbTorrent extension: \(service.split(separator: ".").last ?? "")"
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw Failure(status: added) }
        } else if status != errSecSuccess {
            throw Failure(status: status)
        }
    }

    func delete(service: String, account: String) {
        SecItemDelete(query(service, account) as CFDictionary)
    }
}

/// Keeps secrets in memory, for tests.
final class MemorySecrets: SecretStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func read(service: String, account: String) -> String? {
        lock.withLock { values["\(service)/\(account)"] }
    }

    func write(_ value: String, service: String, account: String) throws {
        lock.withLock { values["\(service)/\(account)"] = value }
    }

    func delete(service: String, account: String) {
        lock.withLock { values["\(service)/\(account)"] = nil }
    }
}

/// What the user set for each extension's settings. Passwords go in the
/// Keychain; only whether one is set is kept here, so drawing the settings
/// never reads the Keychain.
@MainActor
@Observable
final class ExtensionSettings {
    private struct Saved: Codable {
        var values: [String: [String: JSONValue]] = [:]
        var passwordsSet: [String: Set<String>] = [:]
    }

    private var saved: Saved
    @ObservationIgnored private let file: URL
    @ObservationIgnored let secrets: SecretStore

    init(file: URL = ExtensionPaths.settings, secrets: SecretStore = KeychainSecrets()) {
        self.file = file
        self.secrets = secrets
        saved = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } ?? Saved()
    }

    static func service(for name: String) -> String {
        "\(AppIdentity.bundleIdentifier).extension.\(name)"
    }

    /// A setting's value: what the user chose, or its default, or else empty
    /// text, false, or a dropdown's first option. Not for passwords.
    func value(of preference: ExtensionManifest.Preference, in name: String) -> JSONValue {
        if let value = saved.values[name]?[preference.name] { return value }
        if let value = preference.defaultValue { return value }
        switch preference.kind {
        case .checkbox: return .bool(false)
        case .dropdown: return .string(preference.options.first?.value ?? "")
        case .textfield, .password: return .string("")
        }
    }

    func set(_ value: JSONValue, for preference: ExtensionManifest.Preference, in name: String) {
        saved.values[name, default: [:]][preference.name] = value
        save()
    }

    func hasPassword(_ preference: ExtensionManifest.Preference, in name: String) -> Bool {
        saved.passwordsSet[name]?.contains(preference.name) ?? false
    }

    /// Saves a password in the Keychain; empty text removes it.
    func setPassword(_ value: String, for preference: ExtensionManifest.Preference, in name: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            secrets.delete(service: Self.service(for: name), account: preference.name)
            saved.passwordsSet[name]?.remove(preference.name)
        } else {
            try secrets.write(trimmed, service: Self.service(for: name), account: preference.name)
            saved.passwordsSet[name, default: []].insert(preference.name)
        }
        save()
    }

    /// Required settings that are still empty. While there are any, the
    /// extension's hooks are skipped.
    func missing(for item: InstalledExtension) -> [ExtensionManifest.Preference] {
        item.manifest.preferences.filter { preference in
            guard preference.isRequired else { return false }
            switch preference.kind {
            case .password: return !hasPassword(preference, in: item.name)
            case .textfield: return (value(of: preference, in: item.name).string ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            case .checkbox, .dropdown: return false
            }
        }
    }

    /// Every setting's value for a run, reading passwords from the Keychain,
    /// and the passwords themselves, to hide in its logs.
    func resolved(for item: InstalledExtension) async -> (values: [String: JSONValue], secrets: [String]) {
        var values: [String: JSONValue] = [:]
        var passwords: [String] = []
        for preference in item.manifest.preferences where preference.kind != .password {
            values[preference.name] = value(of: preference, in: item.name)
        }
        let secretStore = secrets
        let service = Self.service(for: item.name)
        for preference in item.manifest.preferences where preference.kind == .password {
            // The Keychain can take a moment, or ask the user; not on the main thread.
            let secret = await Task.detached { secretStore.read(service: service, account: preference.name) }.value ?? ""
            values[preference.name] = .string(secret)
            if !secret.isEmpty { passwords.append(secret) }
        }
        return (values, passwords)
    }

    /// Forgets an extension's settings, including its passwords.
    func remove(_ name: String) {
        for account in saved.passwordsSet[name] ?? [] {
            secrets.delete(service: Self.service(for: name), account: account)
        }
        saved.values[name] = nil
        saved.passwordsSet[name] = nil
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(saved).write(to: file, options: .atomic)
        } catch {
            // Kept in memory; saved again with the next change.
        }
    }
}
