import Foundation
import Observation

/// What a hook is given: the `Download` object, and the files on disk it may read.
struct ExtensionDownload: Sendable {
    struct File: Sendable {
        let index: Int
        let path: String
        let size: Int64
        let wanted: Bool
    }

    let id: String
    let name: String
    let isPrivate: Bool
    let files: [File]
    /// Downloaded files by index, for hooks after a download finishes.
    var onDisk: [Int: URL] = [:]

    var json: JSONValue {
        let wantedSize = files.filter(\.wanted).reduce(Int64(0)) { $0 + $1.size }
        let list: [JSONValue] = files.map { file in
            let fields: [String: JSONValue] = [
                "index": .number(Double(file.index)), "path": .string(file.path),
                "size": .number(Double(file.size)), "wanted": .bool(file.wanted),
            ]
            return .object(fields)
        }
        let fields: [String: JSONValue] = [
            "id": .string(id), "name": .string(name), "size": .number(Double(wantedSize)),
            "isPrivate": .bool(isPrivate), "files": .array(list),
        ]
        return .object(fields)
    }

    /// A torrent being asked about, before it's added.
    init(metadata: TorrentMetadata, skipped: Set<Int>) {
        id = metadata.infoHash
        name = metadata.name
        isPrivate = metadata.isPrivate
        files = metadata.files.map { File(index: $0.id, path: $0.path, size: $0.size, wanted: !skipped.contains($0.id)) }
    }

    /// A torrent in the library, with its finished files when it's done.
    init(torrent: Torrent, files: [TorrentFile], includingFilesOnDisk: Bool) {
        id = torrent.hash
        name = torrent.name
        isPrivate = torrent.isPrivate ?? false
        self.files = files.map { File(index: $0.index, path: $0.name, size: $0.size, wanted: $0.isWanted) }
        if includingFilesOnDisk {
            let folder = URL(fileURLWithPath: torrent.savePath, isDirectory: true)
            onDisk = Dictionary(uniqueKeysWithValues: files.filter { $0.isWanted && $0.isComplete }
                .map { ($0.index, folder.appending(path: $0.name)) })
        }
    }
}

/// Runs extensions' hooks at the right moments: before a download starts,
/// holding it if a check fails, and after it finishes.
@MainActor
@Observable
final class Extensions {
    enum Event {
        case check(name: String, hash: String, download: String, record: CheckRecord)
        case progress(name: String, hash: String, download: String, hook: String, progress: CheckProgress)
    }

    let registry: ExtensionRegistry
    let settings: ExtensionSettings
    let checks: ChecksStore
    let logs = ExtensionLogs()
    /// An extension waiting for the user to confirm installing it.
    var installRequest: ExtensionCandidate?
    /// Why the last extension couldn't be installed.
    var installError: String?

    /// A download's files, from the engine.
    @ObservationIgnored var files: ((String) async throws -> [TorrentFile])?
    /// Starts downloads the way the library does.
    @ObservationIgnored var start: (([String]) async -> Void)?
    /// A check held a download before it started.
    @ObservationIgnored var onHeld: ((Torrent, [CheckRecord]) -> Void)?
    /// A check after a download finished found something.
    @ObservationIgnored var onFlagged: ((Torrent, CheckRecord) -> Void)?

    @ObservationIgnored private let runner: ExtensionRunner?
    @ObservationIgnored private var storages: [String: ExtensionStorage] = [:]
    @ObservationIgnored private var runs: [String: Task<CheckRecord, Never>] = [:]
    /// Each extension's runs after downloads finish go one at a time, which suits services' rate limits.
    @ObservationIgnored private var afterFinishTail: [String: Task<CheckRecord, Never>] = [:]
    @ObservationIgnored private var gating: Set<String> = []
    @ObservationIgnored private var knownComplete: [String: Bool]?
    /// Hashes being asked about, whose checks mustn't be forgotten before they're added.
    @ObservationIgnored private var asking: Set<String> = []
    @ObservationIgnored private var listeners: [UUID: (Event) -> Void] = [:]
    @ObservationIgnored private var helpersInUse = 0
    @ObservationIgnored private var helperWaiters: [CheckedContinuation<Void, Never>] = []
    private static let helperLimit = 4

    init(registry: ExtensionRegistry = ExtensionRegistry(), settings: ExtensionSettings = ExtensionSettings(),
         checks: ChecksStore = ChecksStore(), runner: ExtensionRunner? = .bundled) {
        self.registry = registry
        self.settings = settings
        self.checks = checks
        self.runner = runner
        registry.didRemove = { [weak self] name in
            self?.settings.remove(name)
            self?.storages[name] = nil
            try? FileManager.default.removeItem(at: ExtensionPaths.storage(of: name).deletingLastPathComponent())
            self?.logs.clear(name)
        }
    }

    var hasBeforeStartHooks: Bool {
        !registry.hooks(for: .beforeStart).isEmpty
    }

    /// Whether extensions check downloads at all.
    var isOn: Bool { registry.isOn }

    /// Turns extensions off, or back on. Off, running checks stop and
    /// downloads waiting on checks are let go: one meant to start once its
    /// checks passed starts now, and one a check held stays paused for the
    /// user to start.
    func setOn(_ isOn: Bool) {
        guard isOn != registry.isOn else { return }
        registry.isOn = isOn
        guard !isOn else {
            // What finished while they were off isn't checked now.
            registry.restartEnabledClocks()
            return
        }
        for task in runs.values { task.cancel() }
        let gated = checks.gated
        for hash in gated.keys { checks.setGate(nil, for: hash) }
        let starting = gated.filter { $0.value == .waiting }.map(\.key).sorted()
        if !starting.isEmpty { Task { await start?(starting) } }
    }

    // MARK: Before a download starts

    /// Runs every check that's on, together, and keeps their results under the hash.
    func runBeforeStart(on download: ExtensionDownload) async -> [CheckRecord] {
        let hooks = registry.hooks(for: .beforeStart)
        return await withTaskGroup(of: CheckRecord.self) { group in
            for (item, hook) in hooks {
                group.addTask { await self.run(item, hook, on: download, limited: false) }
            }
            var records: [CheckRecord] = []
            for await record in group { records.append(record) }
            return records
        }
    }

    /// Keeps a torrent's checks while it's being asked about.
    func beginAsking(_ hash: String) { asking.insert(hash) }

    /// Stops keeping them; they're forgotten if it wasn't added.
    func endAsking(_ hash: String, added: Bool) {
        asking.remove(hash)
        if !added { cancelRuns(for: hash); checks.forget([hash]) }
    }

    /// A download added so the engine stops it once its files are known, to
    /// start once its checks pass, or stay stopped if the user chose that.
    func gate(_ hash: String, startsAfterChecks: Bool = true) {
        checks.setGate(startsAfterChecks ? .waiting : .checkOnly, for: hash)
    }

    /// Starts a held download, as the user chose.
    func downloadAnyway(_ hash: String) async {
        checks.setGate(nil, for: hash)
        await start?([hash])
    }

    private func runGate(for torrent: Torrent) async {
        let hash = torrent.hash
        defer { gating.remove(hash) }
        guard let files = try? await self.files?(hash) else { return }
        let records = await runBeforeStart(on: ExtensionDownload(torrent: torrent, files: files, includingFilesOnDisk: false))
        // Removed or started by the user meanwhile.
        let gate = checks.gate(for: hash)
        guard gate == .waiting || gate == .checkOnly else { return }
        let failed = records.filter { $0.status == .failed }
        if failed.isEmpty {
            checks.setGate(nil, for: hash)
            if gate == .waiting { await start?([hash]) }
        } else {
            checks.setGate(.held, for: hash)
            onHeld?(torrent, failed)
        }
    }

    // MARK: Watching the library

    /// Called with each refresh of the library.
    func observe(_ torrents: [Torrent]) {
        let present = Set(torrents.map(\.hash))
        let gone = Set(checks.entries.keys).subtracting(present).subtracting(asking)
        if !gone.isEmpty {
            for hash in gone { cancelRuns(for: hash) }
            checks.forget(gone)
        }

        for (hash, gate) in checks.gated where registry.isOn {
            guard let torrent = torrents.first(where: { $0.hash == hash }) else { continue }
            switch gate {
            case .waiting where torrent.hasMetadata && torrent.state.isStopped && !gating.contains(hash),
                 .checkOnly where torrent.hasMetadata && torrent.state.isStopped && !gating.contains(hash):
                gating.insert(hash)
                Task { await runGate(for: torrent) }
            case .waiting where torrent.downloaded > 0 && !torrent.state.isStopped,
                 .checkOnly where torrent.downloaded > 0 && !torrent.state.isStopped:
                // Started by the user before its checks could run.
                checks.setGate(nil, for: hash)
            case .held where !torrent.state.isStopped:
                // The user started it.
                checks.setGate(nil, for: hash)
            default:
                break
            }
        }

        let complete = Dictionary(torrents.map { ($0.hash, $0.isComplete) }, uniquingKeysWith: { $1 })
        defer { knownComplete = complete }
        let hooks = registry.hooks(for: .afterFinish)
        guard !hooks.isEmpty else { return }
        for torrent in torrents where torrent.isComplete {
            for (item, hook) in hooks {
                let id = "\(item.name)/\(hook.name)"
                let record = checks.record(id, for: torrent.hash)
                let finishedSince = (torrent.completedOn ?? .distantPast) > registry.enabledSince(item)
                let due: Bool
                if let knownComplete, let wasComplete = knownComplete[torrent.hash] {
                    due = !wasComplete && torrent.finishedJustNow()
                } else if knownComplete != nil {
                    // New to the library and already finished, such as a small
                    // download that finished between two refreshes.
                    due = record == nil && finishedSince
                } else {
                    // At launch: finished since it was turned on, or interrupted by quitting.
                    due = (record == nil && finishedSince) || record.map { !$0.status.isFinished } == true
                }
                if due && runs["\(torrent.hash)/\(id)"] == nil {
                    Task { await runAfterFinish(item, hook, on: torrent) }
                }
            }
        }
    }

    private func runAfterFinish(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on torrent: Torrent) async {
        guard let files = try? await self.files?(torrent.hash) else { return }
        let download = ExtensionDownload(torrent: torrent, files: files, includingFilesOnDisk: true)
        let record = await run(item, hook, on: download, limited: true)
        if record.status == .failed || record.status == .warning { onFlagged?(torrent, record) }
    }

    // MARK: Running

    /// Runs a hook again, or for the first time, on a download in the library.
    @discardableResult
    func runAgain(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on torrent: Torrent) async -> CheckRecord? {
        guard let files = try? await self.files?(torrent.hash) else { return nil }
        let afterFinish = hook.event == .afterFinish
        let download = ExtensionDownload(torrent: torrent, files: files, includingFilesOnDisk: afterFinish && torrent.isComplete)
        let record = await run(item, hook, on: download, limited: afterFinish)
        // A held download that now passes its checks can start.
        if hook.event == .beforeStart, checks.gate(for: torrent.hash) == .held,
           !checks.records(for: torrent.hash).contains(where: { $0.event == .beforeStart && $0.status == .failed }) {
            await downloadAnyway(torrent.hash)
        }
        return record
    }

    /// Runs one hook on a download as it's given.
    func run(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on download: ExtensionDownload) async -> CheckRecord {
        await run(item, hook, on: download, limited: hook.event == .afterFinish)
    }

    private func run(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on download: ExtensionDownload,
                     limited: Bool) async -> CheckRecord {
        let key = "\(download.id)/\(item.name)/\(hook.name)"
        runs[key]?.cancel()
        var queued = CheckRecord(extension: item, hook: hook, status: limited ? .queued : .running, summary: "Waiting to run")
        queued.startedAt = .now
        checks.update(queued, for: download.id)
        let previous = limited ? afterFinishTail[item.name] : nil
        let task = Task { () -> CheckRecord in
            _ = await previous?.value
            if Task.isCancelled { return self.finish(queued, .skipped, "Stopped", on: download) }
            if limited { await self.takeHelper() }
            defer { if limited { self.releaseHelper() } }
            return await self.execute(item, hook, on: download)
        }
        runs[key] = task
        if limited { afterFinishTail[item.name] = task }
        let record = await task.value
        if runs[key] == task { runs[key] = nil }
        return record
    }

    private func execute(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on download: ExtensionDownload) async -> CheckRecord {
        var record = CheckRecord(extension: item, hook: hook, status: .running, summary: "Checking…")
        record.startedAt = .now
        checks.update(record, for: download.id)
        emit(.check(name: item.name, hash: download.id, download: download.name, record: record))

        guard item.isCompatible else {
            return finish(record, .skipped, "Needs a newer version of OrbTorrent", on: download)
        }
        let missing = settings.missing(for: item)
        if !missing.isEmpty {
            return finish(record, .skipped, "Needs setup: \(ListFormatter.localizedString(byJoining: missing.map(\.title)))", on: download)
        }
        guard let runner else {
            return finish(record, .didNotFinish, "OrbTorrent's extension host is missing. Reinstall OrbTorrent.", on: download)
        }
        guard let script = try? String(contentsOf: item.script(for: hook), encoding: .utf8) else {
            return finish(record, .didNotFinish, "Its script couldn't be read. Reinstall the extension.", on: download)
        }
        let resolved = await settings.resolved(for: item)
        let limits: ExtensionLimits = hook.event == .beforeStart ? .beforeStart : .afterFinish
        let job = ExtensionJob(script: script, arguments: [download.json],
                               context: context(for: item, entryPoint: ["type": "hook", "name": .string(hook.name), "event": .string(hook.event.rawValue)],
                                                preferences: resolved.values),
                               limits: limits)
        let recordID = record.id
        let services = ExtensionServices(
            network: ExtensionNetwork(extensionName: item.name, permissions: item.manifest.permissions),
            files: download.onDisk, storage: storage(for: item.name), secrets: resolved.secrets,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    self?.checks.change(recordID, for: download.id) { $0.progress = progress }
                    self?.emit(.progress(name: item.name, hash: download.id, download: download.name, hook: hook.name, progress: progress))
                }
            },
            onLog: logger(for: item, entryPoint: hook.name, download: download.name))
        let outcome = await runner.run(job, handler: services)
        return conclude(record, outcome, limits: limits, item: item, entryPoint: hook.name, download: download)
    }

    private func conclude(_ record: CheckRecord, _ outcome: ExtensionOutcome, limits: ExtensionLimits,
                          item: InstalledExtension, entryPoint: String, download: ExtensionDownload) -> CheckRecord {
        switch outcome {
        case .returned(let value):
            guard let status = value["status"]?.string.flatMap(CheckRecord.Status.init(rawValue:)),
                  [.passed, .warning, .failed, .skipped].contains(status),
                  let summary = value["summary"]?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty else {
                return finish(record, .didNotFinish, "It returned something that isn't a result: return { status, summary }.", on: download)
            }
            var finished = record
            finished.details = value["details"]?.string.map { String($0.prefix(20_000)) }
            if let title = value["link"]?["title"]?.string, let text = value["link"]?["url"]?.string,
               let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? "") {
                finished.link = CheckRecord.Link(title: String(title.prefix(60)), url: url)
            }
            let line = summary.replacingOccurrences(of: "\n", with: " ")
            return finish(finished, status, String(line.prefix(300)), on: download)
        case .threw(let message, let stack):
            if !stack.isEmpty {
                logs.append(ExtensionLogEntry(date: .now, level: "error", message: "\(message)\n\(stack)", entryPoint: entryPoint, download: download.name), for: item.name)
            }
            return finish(record, .didNotFinish, "Didn't finish: \(message)", on: download)
        case .stopped(.time):
            return finish(record, .didNotFinish, "Didn't finish: it took longer than \(Self.describe(limits.time))", on: download)
        case .stopped(.cpuTime):
            return finish(record, .didNotFinish, "Didn't finish: it kept the processor busy for over \(Self.describe(limits.cpuTime))", on: download)
        case .stopped(.memory):
            return finish(record, .didNotFinish, "Didn't finish: it used more than \(limits.memory >> 20) MB of memory", on: download)
        case .stopped(.cancelled):
            return finish(record, .skipped, "Stopped", on: download)
        case .crashed(let message):
            return finish(record, .didNotFinish, "Didn't finish: \(message)", on: download)
        case .couldNotStart(let message):
            return finish(record, .didNotFinish, "Couldn't start: \(message)", on: download)
        }
    }

    private func finish(_ record: CheckRecord, _ status: CheckRecord.Status, _ summary: String, on download: ExtensionDownload) -> CheckRecord {
        var finished = record
        finished.status = status
        finished.summary = summary
        finished.progress = nil
        finished.finishedAt = .now
        checks.update(finished, for: download.id)
        emit(.check(name: record.extensionName, hash: download.id, download: download.name, record: finished))
        return finished
    }

    private static func describe(_ duration: Duration) -> String {
        let seconds = Int(duration.components.seconds)
        return seconds >= 3600 ? "\(seconds / 3600) h" : seconds >= 60 ? "\(seconds / 60) min" : "\(seconds) s"
    }

    // MARK: Settings

    /// Runs the extension's settings check, for the Verify button.
    func verify(_ item: InstalledExtension) async -> (ok: Bool, message: String) {
        guard let url = item.verifyScript, let script = try? String(contentsOf: url, encoding: .utf8) else {
            return (false, "This extension can't check its settings.")
        }
        guard let runner else { return (false, "OrbTorrent's extension host is missing. Reinstall OrbTorrent.") }
        let resolved = await settings.resolved(for: item)
        let job = ExtensionJob(script: script, arguments: [.object(resolved.values)],
                               context: context(for: item, entryPoint: ["type": "verify", "name": .string(item.manifest.verify ?? "verify")],
                                                preferences: resolved.values),
                               limits: .verify)
        let services = ExtensionServices(
            network: ExtensionNetwork(extensionName: item.name, permissions: item.manifest.permissions),
            files: [:], storage: storage(for: item.name), secrets: resolved.secrets,
            onProgress: { _ in }, onLog: logger(for: item, entryPoint: "verify", download: nil))
        switch await runner.run(job, handler: services) {
        case .returned(let value):
            let message = value["message"]?.string ?? ""
            if value["ok"]?.bool == true { return (true, message.isEmpty ? "The settings work." : message) }
            return (false, message.isEmpty ? "The settings don't work." : message)
        case .threw(let message, _): return (false, "Couldn't check: \(message)")
        case .stopped: return (false, "Couldn't check: it took too long.")
        case .crashed(let message), .couldNotStart(let message): return (false, "Couldn't check: \(message)")
        }
    }

    // MARK: Helpers

    private func context(for item: InstalledExtension, entryPoint: JSONValue, preferences: [String: JSONValue]) -> JSONValue {
        [
            "extension": ["name": .string(item.name), "title": .string(item.title), "isDevelopment": .bool(item.source == .development)],
            "entryPoint": entryPoint,
            "preferences": .object(preferences),
            "api": .string(ExtensionAPI.versionString),
        ]
    }

    private func logger(for item: InstalledExtension, entryPoint: String, download: String?) -> @Sendable (String, String) -> Void {
        let name = item.name
        return { [weak self] level, message in
            Task { @MainActor in
                self?.logs.append(ExtensionLogEntry(date: .now, level: level, message: message, entryPoint: entryPoint, download: download), for: name)
            }
        }
    }

    private func storage(for name: String) -> ExtensionStorage {
        if let storage = storages[name] { return storage }
        let storage = ExtensionStorage(file: ExtensionPaths.storage(of: name))
        storages[name] = storage
        return storage
    }

    private func cancelRuns(for hash: String) {
        for (key, task) in runs where key.hasPrefix("\(hash)/") { task.cancel() }
    }

    private func takeHelper() async {
        if helpersInUse < Self.helperLimit {
            helpersInUse += 1
            return
        }
        await withCheckedContinuation { helperWaiters.append($0) }
    }

    private func releaseHelper() {
        if helperWaiters.isEmpty {
            helpersInUse -= 1
        } else {
            helperWaiters.removeFirst().resume()
        }
    }

    // MARK: Events, for development

    func listen(_ listener: @escaping (Event) -> Void) -> UUID {
        let id = UUID()
        listeners[id] = listener
        return id
    }

    func stopListening(_ id: UUID) {
        listeners[id] = nil
    }

    private func emit(_ event: Event) {
        for listener in listeners.values { listener(event) }
    }
}
