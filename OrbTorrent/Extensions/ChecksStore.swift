import Foundation
import Observation

extension ExtensionManifest.Event: Codable {}

/// One extension hook's result on a download, as the Checks tab shows it.
struct CheckRecord: Codable, Identifiable, Sendable, Equatable {
    enum Status: String, Codable, Sendable {
        case queued, running, passed, warning, failed, skipped
        /// It threw, crashed, or went over a limit.
        case didNotFinish

        var isFinished: Bool { self != .queued && self != .running }
    }

    struct Link: Codable, Sendable, Equatable {
        let title: String
        let url: URL
    }

    let extensionName: String
    var extensionTitle: String
    let hookName: String
    var hookTitle: String
    let event: ExtensionManifest.Event
    var status: Status
    var summary: String
    var details: String?
    var link: Link?
    var progress: CheckProgress?
    var startedAt: Date?
    var finishedAt: Date?

    var id: String { "\(extensionName)/\(hookName)" }

    init(extension item: InstalledExtension, hook: ExtensionManifest.Hook, status: Status, summary: String) {
        extensionName = item.name
        extensionTitle = item.title
        hookName = hook.name
        hookTitle = hook.title
        event = hook.event
        self.status = status
        self.summary = summary
    }
}

/// Check results for every download, and which downloads wait on their
/// checks before starting. Kept across restarts.
@MainActor
@Observable
final class ChecksStore {
    enum Gate: String, Codable, Sendable {
        /// Added stopped until its file list is known and its checks pass.
        case waiting
        /// Added to stay stopped: its checks run once its file list is known.
        case checkOnly
        /// A check failed: it stays stopped until the user decides.
        case held
    }

    /// What a download's row shows about its checks.
    enum Badge: Equatable {
        case checking, held, failed, warning
    }

    struct Entry: Codable, Equatable {
        var records: [CheckRecord] = []
        var gate: Gate?
    }

    private(set) var entries: [String: Entry]
    @ObservationIgnored private let file: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(file: URL = ExtensionPaths.checks) {
        self.file = file
        entries = (try? Data(contentsOf: file)).flatMap { try? JSONDecoder().decode([String: Entry].self, from: $0) } ?? [:]
    }

    func records(for hash: String) -> [CheckRecord] {
        entries[hash]?.records ?? []
    }

    func record(_ id: String, for hash: String) -> CheckRecord? {
        entries[hash]?.records.first { $0.id == id }
    }

    func update(_ record: CheckRecord, for hash: String) {
        var entry = entries[hash] ?? Entry()
        if let index = entry.records.firstIndex(where: { $0.id == record.id }) {
            guard entry.records[index] != record else { return }
            entry.records[index] = record
        } else {
            entry.records.append(record)
        }
        entries[hash] = entry
        scheduleSave()
    }

    func change(_ id: String, for hash: String, _ body: (inout CheckRecord) -> Void) {
        guard var record = record(id, for: hash) else { return }
        body(&record)
        update(record, for: hash)
    }

    func gate(for hash: String) -> Gate? {
        entries[hash]?.gate
    }

    func setGate(_ gate: Gate?, for hash: String) {
        guard entries[hash]?.gate != gate else { return }
        entries[hash, default: Entry()].gate = gate
        scheduleSave()
    }

    /// Hashes of downloads that wait on their checks or are held.
    var gated: [String: Gate] {
        entries.compactMapValues(\.gate)
    }

    func forget(_ hashes: some Sequence<String>) {
        var changed = false
        for hash in hashes where entries.removeValue(forKey: hash) != nil { changed = true }
        if changed { scheduleSave() }
    }

    func badge(for hash: String) -> Badge? {
        guard let entry = entries[hash] else { return nil }
        if entry.gate == .held { return .held }
        let statuses = entry.records.map(\.status)
        if statuses.contains(.failed) { return .failed }
        if statuses.contains(.warning) { return .warning }
        if entry.gate == .waiting || entry.gate == .checkOnly || statuses.contains(where: { !$0.isFinished }) { return .checking }
        return nil
    }

    /// Saves once changes settle, as progress can change often.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
        } catch {
            // Tried again with the next change.
        }
    }
}

/// A line an extension logged.
struct ExtensionLogEntry: Identifiable, Sendable, Equatable {
    let id = UUID()
    let date: Date
    let level: String
    let message: String
    /// The hook or verify, and the download it ran on.
    let entryPoint: String?
    let download: String?
}

/// What each extension logged recently, and in its log file.
@MainActor
@Observable
final class ExtensionLogs {
    private(set) var entries: [String: [ExtensionLogEntry]] = [:]
    /// Development connections watching an extension's logs.
    @ObservationIgnored private var listeners: [UUID: (String, ExtensionLogEntry) -> Void] = [:]
    @ObservationIgnored private let writer = DispatchQueue(label: "OrbTorrent.extension-logs")
    private static let kept = 500
    private nonisolated static let fileLimit = 1 << 20

    func append(_ entry: ExtensionLogEntry, for name: String) {
        var list = entries[name] ?? []
        list.append(entry)
        if list.count > Self.kept { list.removeFirst(list.count - Self.kept) }
        entries[name] = list
        for listener in listeners.values { listener(name, entry) }

        let line = "\(entry.date.formatted(.iso8601)) [\(entry.level)] \(entry.entryPoint.map { "\($0) " } ?? "")\(entry.download.map { "(\($0)) " } ?? "")\(entry.message)\n"
        let file = ExtensionPaths.log(of: name)
        writer.async {
            let manager = FileManager.default
            try? manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Keeps one older file when it grows past 1 MB.
            if let size = (try? manager.attributesOfItem(atPath: file.path))?[.size] as? Int, size > Self.fileLimit {
                let older = file.appendingPathExtension("1")
                try? manager.removeItem(at: older)
                try? manager.moveItem(at: file, to: older)
            }
            if !manager.fileExists(atPath: file.path) { manager.createFile(atPath: file.path, contents: nil) }
            if let handle = try? FileHandle(forWritingTo: file) {
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
                try? handle.close()
            }
        }
    }

    func clear(_ name: String) {
        entries[name] = nil
    }

    func listen(_ listener: @escaping (String, ExtensionLogEntry) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        return id
    }

    func stopListening(_ id: UUID) {
        listeners[id] = nil
    }
}
