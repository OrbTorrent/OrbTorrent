import Foundation
import Observation

/// An extension OrbTorrent can run: its manifest, its built files and where it came from.
struct InstalledExtension: Identifiable, Sendable, Equatable {
    enum Source: String, Sendable {
        /// Built by us and shipped inside OrbTorrent.
        case official
        /// Installed from an .orbext file or a folder.
        case installed
        /// Loaded from a folder by `orb dev` or `orb run`.
        case development
    }

    let manifest: ExtensionManifest
    /// The built extension: `package.json`, `hooks/` and its assets.
    let folder: URL
    let source: Source
    /// A development copy standing in for the official extension of the same name.
    var replacesOfficial = false

    var id: String { manifest.name }
    var name: String { manifest.name }
    var title: String { manifest.title }

    var iconURL: URL? {
        guard let icon = manifest.icon else { return nil }
        let url = folder.appending(path: "assets/\(icon)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Setup steps from help.md, shown beside its settings.
    var help: String? {
        (try? String(contentsOf: folder.appending(path: "help.md"), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func script(for hook: ExtensionManifest.Hook) -> URL {
        folder.appending(path: "hooks/\(hook.name).js")
    }

    var verifyScript: URL? {
        manifest.verify == nil ? nil : folder.appending(path: "verify.js")
    }

    /// Whether this OrbTorrent has the API it was built for.
    var isCompatible: Bool {
        manifest.apiVersion.map(ExtensionAPI.supports) ?? true
    }

    /// Reads a built extension, checking its files are all there.
    static func load(from folder: URL, source: Source) throws -> InstalledExtension {
        let data: Data
        do {
            data = try Data(contentsOf: folder.appending(path: "package.json"))
        } catch {
            throw ExtensionManifest.Invalid(problems: ["There's no package.json. Build the extension with `orb build` and choose its dist folder."])
        }
        let manifest = try ExtensionManifest(data: data)
        let loaded = InstalledExtension(manifest: manifest, folder: folder, source: source)
        var missing = manifest.hooks.filter { !FileManager.default.fileExists(atPath: loaded.script(for: $0).path) }
            .map { "hooks/\($0.name).js is missing. Build the extension with `orb build`." }
        if let verify = loaded.verifyScript, !FileManager.default.fileExists(atPath: verify.path) {
            missing.append("verify.js is missing. Build the extension with `orb build`.")
        }
        if !missing.isEmpty { throw ExtensionManifest.Invalid(problems: missing) }
        return loaded
    }
}

/// A folder that should hold an extension but couldn't be loaded.
struct ExtensionProblem: Identifiable, Sendable, Equatable {
    let folder: URL
    let source: InstalledExtension.Source
    let message: String
    var id: String { folder.path }
}

/// An extension about to be installed from a file or folder, for the install sheet.
struct ExtensionCandidate: Identifiable, Sendable {
    let `extension`: InstalledExtension
    /// The version already installed, when this replaces it.
    let existing: InstalledExtension?
    /// What it can do that the installed version couldn't.
    let newAbilities: Set<String>
    /// A temporary copy, removed once it's installed or cancelled.
    let staging: URL
    var id: String { `extension`.name }
}

/// The extensions OrbTorrent knows about, which are on, and which can be
/// loaded for development.
@MainActor
@Observable
final class ExtensionRegistry {
    /// One per name: a development copy stands in for an installed or official one.
    private(set) var extensions: [InstalledExtension] = []
    private(set) var problems: [ExtensionProblem] = []
    /// Whether extensions check downloads at all. Off, OrbTorrent is a plain
    /// torrent client: nothing runs and no checks show, but every extension
    /// and its settings are kept for when they're back on.
    var isOn: Bool {
        didSet { defaults.set(isOn, forKey: Keys.isOn) }
    }
    /// Whether `orb dev` and `orb run` may load extensions from folders.
    var allowsDevelopment: Bool {
        didSet { defaults.set(allowsDevelopment, forKey: Keys.allowsDevelopment) }
    }
    /// Called when an extension is removed, to delete its settings and storage.
    @ObservationIgnored var didRemove: ((String) -> Void)?

    private var enabled: [String: Bool] {
        didSet { defaults.set(enabled, forKey: Keys.enabled) }
    }
    /// When each extension was last turned on, so finished downloads from
    /// before then aren't scanned at launch.
    private var enabledAt: [String: Date] {
        didSet { defaults.set(enabledAt, forKey: Keys.enabledAt) }
    }
    /// The built folders `orb dev` has loaded, kept until removed.
    private var developmentFolders: [String] {
        didSet { defaults.set(developmentFolders, forKey: Keys.developmentFolders) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let officialFolder: URL?
    @ObservationIgnored private let installedFolder: URL

    /// Official extensions that are on until turned off. Others wait to be
    /// turned on, such as one that needs an account.
    static let onByDefault: Set<String> = ["fake-download-check"]

    private enum Keys {
        static let isOn = "extensionsOn"
        static let enabled = "extensionsEnabled"
        static let enabledAt = "extensionsEnabledAt"
        static let developmentFolders = "developmentExtensions"
        static let allowsDevelopment = "allowsDevelopmentExtensions"
    }

    init(defaults: UserDefaults = .standard, officialFolder: URL? = ExtensionPaths.official,
         installedFolder: URL = ExtensionPaths.installed) {
        self.defaults = defaults
        self.officialFolder = officialFolder
        self.installedFolder = installedFolder
        enabled = defaults.dictionary(forKey: Keys.enabled) as? [String: Bool] ?? [:]
        enabledAt = defaults.dictionary(forKey: Keys.enabledAt) as? [String: Date] ?? [:]
        developmentFolders = defaults.stringArray(forKey: Keys.developmentFolders) ?? []
        allowsDevelopment = defaults.bool(forKey: Keys.allowsDevelopment)
        isOn = defaults.object(forKey: Keys.isOn) as? Bool ?? true
        reload()
    }

    // MARK: Loading

    func reload() {
        var found: [InstalledExtension] = []
        var problems: [ExtensionProblem] = []
        func scan(_ folder: URL?, as source: InstalledExtension.Source) {
            guard let folder, let entries = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
            for entry in entries.sorted(by: { $0.path < $1.path })
            where (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                do {
                    found.append(try InstalledExtension.load(from: entry, source: source))
                } catch {
                    problems.append(ExtensionProblem(folder: entry, source: source, message: error.localizedDescription))
                }
            }
        }
        scan(officialFolder, as: .official)
        scan(installedFolder, as: .installed)
        for path in developmentFolders {
            let folder = URL(fileURLWithPath: path, isDirectory: true)
            do {
                found.append(try InstalledExtension.load(from: folder, source: .development))
            } catch {
                problems.append(ExtensionProblem(folder: folder, source: .development, message: error.localizedDescription))
            }
        }

        // One per name: development first, then installed, then official.
        let rank: [InstalledExtension.Source: Int] = [.development: 0, .installed: 1, .official: 2]
        var byName: [String: InstalledExtension] = [:]
        for candidate in found.sorted(by: { rank[$0.source]! < rank[$1.source]! }) where byName[candidate.name] == nil {
            var chosen = candidate
            chosen.replacesOfficial = candidate.source == .development
                && found.contains { $0.name == candidate.name && $0.source == .official }
            byName[candidate.name] = chosen
        }
        let order: [InstalledExtension.Source: Int] = [.official: 0, .installed: 1, .development: 1]
        let sorted = byName.values.sorted {
            (order[$0.source]!, $0.title.localizedLowercase) < (order[$1.source]!, $1.title.localizedLowercase)
        }
        if sorted != extensions { extensions = sorted }
        if problems != self.problems { self.problems = problems }
    }

    func named(_ name: String) -> InstalledExtension? {
        extensions.first { $0.name == name }
    }

    // MARK: On and off

    func isEnabled(_ item: InstalledExtension) -> Bool {
        if let value = enabled[item.name] { return value }
        switch item.source {
        case .official: return Self.onByDefault.contains(item.name)
        case .installed, .development: return true
        }
    }

    func setEnabled(_ isOn: Bool, for item: InstalledExtension) {
        enabled[item.name] = isOn
        if isOn { enabledAt[item.name] = .now }
    }

    /// When it was turned on, or when OrbTorrent first saw it if it's on by default.
    func enabledSince(_ item: InstalledExtension) -> Date {
        if let date = enabledAt[item.name] { return date }
        let now = Date.now
        enabledAt[item.name] = now
        return now
    }

    /// Counts each extension that's on as turned on now, so what finished
    /// while extensions were off isn't checked at the next launch.
    func restartEnabledClocks() {
        for item in extensions where isEnabled(item) { enabledAt[item.name] = .now }
    }

    /// The hooks that run at a moment, from extensions that are on. None
    /// while extensions are off.
    func hooks(for event: ExtensionManifest.Event) -> [(InstalledExtension, ExtensionManifest.Hook)] {
        guard isOn else { return [] }
        return extensions.filter(isEnabled).flatMap { item in item.manifest.hooks(for: event).map { (item, $0) } }
    }

    // MARK: Installing

    /// Reads an .orbext file or an extension's folder, ready for the install sheet.
    func inspect(_ url: URL) throws -> ExtensionCandidate {
        let staging = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-install-\(UUID().uuidString)", directoryHint: .isDirectory)
        do {
            try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
            let root = staging.appending(path: "extension", directoryHint: .isDirectory)
            if url.pathExtension.lowercased() == "orbext" {
                try Self.unzip(url, to: root)
            } else {
                // A source folder has its build in dist/.
                let built = FileManager.default.fileExists(atPath: url.appending(path: "dist/package.json").path)
                    ? url.appending(path: "dist", directoryHint: .isDirectory) : url
                try FileManager.default.copyItem(at: built, to: root)
            }
            try Self.checkContents(of: root)
            let item = try InstalledExtension.load(from: root, source: .installed)
            if let officialFolder, FileManager.default.fileExists(atPath: officialFolder.appending(path: "\(item.name)/package.json").path) {
                throw ExtensionManifest.Invalid(problems: ["“\(item.name)” is the name of an official extension, so another can't use it."])
            }
            let existing = extensions.first { $0.name == item.name && $0.source == .installed }
            let newAbilities = Set(item.manifest.abilities).subtracting(existing?.manifest.abilities ?? [])
            return ExtensionCandidate(extension: item, existing: existing, newAbilities: existing == nil ? [] : newAbilities, staging: staging)
        } catch {
            try? FileManager.default.removeItem(at: staging)
            throw error
        }
    }

    func install(_ candidate: ExtensionCandidate) throws {
        defer { try? FileManager.default.removeItem(at: candidate.staging) }
        let target = installedFolder.appending(path: candidate.extension.name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: installedFolder, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: target.path) {
            _ = try FileManager.default.replaceItemAt(target, withItemAt: candidate.extension.folder)
        } else {
            try FileManager.default.moveItem(at: candidate.extension.folder, to: target)
        }
        if enabled[candidate.extension.name] != false { setEnabled(true, for: candidate.extension) }
        reload()
    }

    func cancel(_ candidate: ExtensionCandidate) {
        try? FileManager.default.removeItem(at: candidate.staging)
    }

    /// Removes an installed or development extension, with its settings and storage.
    func remove(_ item: InstalledExtension) {
        switch item.source {
        case .official:
            return
        case .installed:
            try? FileManager.default.removeItem(at: item.folder)
        case .development:
            developmentFolders.removeAll { $0 == item.folder.path }
        }
        reload()
        // Removing a development copy leaves the extension it stood in for, with its settings.
        if named(item.name) == nil {
            enabled[item.name] = nil
            enabledAt[item.name] = nil
            didRemove?(item.name)
        }
    }

    // MARK: Development

    /// Whether this built folder has been loaded before, so it needn't be asked about.
    func isKnownDevelopmentFolder(_ folder: URL) -> Bool {
        let path = folder.resolvingSymlinksInPath().path
        return developmentFolders.contains { URL(fileURLWithPath: $0).resolvingSymlinksInPath().path == path }
    }

    /// Loads, or reloads, an extension from a folder for development.
    @discardableResult
    func loadDevelopment(from folder: URL) throws -> InstalledExtension {
        let folder = folder.resolvingSymlinksInPath()
        let item = try InstalledExtension.load(from: folder, source: .development)
        guard item.isCompatible else {
            throw ExtensionManifest.Invalid(problems: ["It was built with @orbtorrent/api \(item.manifest.apiVersion ?? "?"), which needs a newer OrbTorrent."])
        }
        // Another folder with the same name is replaced by this one.
        developmentFolders.removeAll { path in
            path != folder.path && (try? InstalledExtension.load(from: URL(fileURLWithPath: path), source: .development))?.name == item.name
        }
        if !developmentFolders.contains(folder.path) { developmentFolders.append(folder.path) }
        reload()
        return named(item.name) ?? item
    }

    // MARK: Files

    private static func unzip(_ archive: URL, to folder: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", archive.path, folder.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ExtensionManifest.Invalid(problems: ["The file couldn't be opened. It may be damaged, or not an OrbTorrent extension."])
        }
    }

    /// Refuses links, which could point outside the extension, and very large packages.
    private static func checkContents(of folder: URL) throws {
        var total = 0
        let keys: [URLResourceKey] = [.isSymbolicLinkKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: keys) else { return }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            if values.isSymbolicLink == true {
                throw ExtensionManifest.Invalid(problems: ["It contains a link (\(url.lastPathComponent)), which extensions can't include."])
            }
            total += values.fileSize ?? 0
        }
        if total > 50 << 20 {
            throw ExtensionManifest.Invalid(problems: ["It's larger than 50 MB, the most an extension can be."])
        }
    }
}
