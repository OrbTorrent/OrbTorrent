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
    /// The folder it's saved in, where files the extension adds go.
    var folder: URL?
    /// After it finishes: the files the hook hasn't seen finished before,
    /// which `isNew` marks. Nil before it finishes.
    var newFiles: Set<Int>?
    /// For a report on the checks: the other checks' results.
    var checks: [CheckRecord]?
    /// For a report on the checks: whether one held it before it started.
    var isHeld = false

    var json: JSONValue {
        let wantedSize = files.filter(\.wanted).reduce(Int64(0)) { $0 + $1.size }
        let list: [JSONValue] = files.map { file in
            var fields: [String: JSONValue] = [
                "index": .number(Double(file.index)), "path": .string(file.path),
                "size": .number(Double(file.size)), "wanted": .bool(file.wanted),
            ]
            if let newFiles { fields["isNew"] = .bool(newFiles.contains(file.index)) }
            return .object(fields)
        }
        var fields: [String: JSONValue] = [
            "id": .string(id), "name": .string(name), "size": .number(Double(wantedSize)),
            "isPrivate": .bool(isPrivate), "files": .array(list),
        ]
        if let checks {
            fields["checks"] = .array(checks.map(Self.json))
            fields["isHeld"] = .bool(isHeld)
        }
        return .object(fields)
    }

    /// Another check's result, as a report on the checks sees it.
    private static func json(_ record: CheckRecord) -> JSONValue {
        func link(_ link: CheckRecord.Link) -> JSONValue {
            ["title": .string(link.title), "url": .string(link.url.absoluteString)]
        }
        var fields: [String: JSONValue] = [
            "extension": ["name": .string(record.extensionName), "title": .string(record.extensionTitle)],
            "hook": .string(record.hookName), "event": .string(record.event.rawValue),
            "status": .string(record.status.rawValue), "summary": .string(record.summary),
        ]
        if let details = record.details { fields["details"] = .string(details) }
        if let value = record.link { fields["link"] = link(value) }
        if let files = record.files {
            fields["files"] = .array(files.map { file in
                var entry: [String: JSONValue] = [
                    "index": .number(Double(file.index)), "path": .string(file.path), "status": .string(file.status.rawValue),
                ]
                if let summary = file.summary { entry["summary"] = .string(summary) }
                if let value = file.link { entry["link"] = link(value) }
                return .object(entry)
            })
        }
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
        if includingFilesOnDisk, !torrent.savePath.isEmpty {
            let folder = URL(fileURLWithPath: torrent.savePath, isDirectory: true)
            self.folder = folder
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
    /// A check asked for its result to be a notification, with `notify: true`:
    /// the download's hash and name, and the result.
    @ObservationIgnored var onNotice: ((String, String, CheckRecord) -> Void)?

    @ObservationIgnored private let runner: ExtensionRunner?
    @ObservationIgnored private var storages: [String: ExtensionStorage] = [:]
    @ObservationIgnored private var runs: [String: Task<CheckRecord, Never>] = [:]
    /// Each extension's runs after downloads finish go one at a time, which suits services' rate limits.
    @ObservationIgnored private var afterFinishTail: [String: Task<CheckRecord, Never>] = [:]
    /// The checks a download gets once it finishes, by hash, while they run.
    @ObservationIgnored private var finishing: [String: Task<[CheckRecord], Never>] = [:]
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
            // Those reporting on the checks hear why.
            let reports = registry.hooks(for: .afterChecks)
            Task { await self.runReports(reports, on: torrent, held: true) }
        }
        // Holding it was a notification already.
        for record in records where record.notify == true && record.status != .failed {
            onNotice?(hash, torrent.name, record)
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
            // Only a download that may be talking to peers was started: one
            // the engine is checking, queueing or moving may still be stopped.
            case .waiting where torrent.downloaded > 0 && torrent.state.mayHavePeers,
                 .checkOnly where torrent.downloaded > 0 && torrent.state.mayHavePeers:
                // Started by the user before its checks could run.
                checks.setGate(nil, for: hash)
            case .held where torrent.state.mayHavePeers:
                // The user started it.
                checks.setGate(nil, for: hash)
            default:
                break
            }
        }

        let complete = Dictionary(torrents.map { ($0.hash, $0.isComplete) }, uniquingKeysWith: { $1 })
        defer { knownComplete = complete }
        let hooks = registry.hooks(for: .afterFinish)
        let reports = registry.hooks(for: .afterChecks)
        guard !hooks.isEmpty || !reports.isEmpty else { return }
        for torrent in torrents where torrent.isComplete {
            let due = hooks.filter { isDue($0.0, $0.1, on: torrent) }
            let dueReports = reports.filter { isDue($0.0, $0.1, on: torrent) }
            guard !due.isEmpty || !dueReports.isEmpty else { continue }
            let previous = finishing[torrent.hash]
            let task = Task { () -> [CheckRecord] in
                let earlier = await previous?.value ?? []
                let records = await withTaskGroup(of: CheckRecord?.self) { group in
                    for (item, hook) in due {
                        group.addTask { await self.runAfterFinish(item, hook, on: torrent) }
                    }
                    var records: [CheckRecord] = []
                    for await record in group { if let record { records.append(record) } }
                    return records
                }
                return earlier + records
            }
            finishing[torrent.hash] = task
            Task {
                _ = await task.value
                if finishing[torrent.hash] == task { finishing[torrent.hash] = nil }
                // Then the reports, with what the checks found.
                await runReports(dueReports, on: torrent, held: false)
            }
        }
    }

    /// Whether a hook that runs once a download finishes should run on it now.
    private func isDue(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on torrent: Torrent) -> Bool {
        let id = "\(item.name)/\(hook.name)"
        guard runs["\(torrent.hash)/\(id)"] == nil else { return false }
        let record = checks.record(id, for: torrent.hash)
        let completed = torrent.completedOn ?? .distantPast
        let finishedSince = completed > registry.enabledSince(item)
        if let knownComplete, let wasComplete = knownComplete[torrent.hash] {
            // It finished just now: for the first time, or again once the
            // user chose more of its files.
            return !wasComplete && torrent.finishedJustNow()
        } else if knownComplete != nil {
            // New to the library and already finished, such as a small
            // download that finished between two refreshes.
            return record == nil && finishedSince
        } else {
            // At launch: finished since it was turned on, and not run on since
            // it finished, or interrupted by quitting.
            let ranSince = record?.startedAt.map { $0 >= completed } ?? false
            return (finishedSince && !ranSince) || record.map { !$0.status.isFinished } == true
        }
    }

    /// The results of the checks a download gets once it finishes, after
    /// they've all run; none if it gets none. For "When a download finishes,
    /// run", which waits for them.
    func afterFinishChecks(for hash: String) async -> [CheckRecord] {
        await finishing[hash]?.value ?? []
    }

    private func runAfterFinish(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on torrent: Torrent) async -> CheckRecord? {
        guard let files = try? await self.files?(torrent.hash) else { return nil }
        let previous = checks.record("\(item.name)/\(hook.name)", for: torrent.hash)
        var download = ExtensionDownload(torrent: torrent, files: files, includingFilesOnDisk: true)
        download.newFiles = Set(download.onDisk.keys).subtracting(previous?.seenFiles ?? [])
        let record = await run(item, hook, on: download, limited: true)
        // What the user was already told, such as before they chose more of
        // its files, isn't said again.
        if record.flagsMore(than: previous) {
            onFlagged?(torrent, record)
        } else if record.notify == true {
            onNotice?(torrent.hash, torrent.name, record)
        }
        return record
    }

    // MARK: Reports on the checks

    /// Runs the hooks that report on a download's checks, once the checks are
    /// done: after it finishes, or when one holds it before it starts.
    private func runReports(_ hooks: [(InstalledExtension, ExtensionManifest.Hook)], on torrent: Torrent, held: Bool) async {
        guard !hooks.isEmpty, let files = try? await self.files?(torrent.hash) else { return }
        await withTaskGroup(of: Void.self) { group in
            for (item, hook) in hooks {
                group.addTask { await self.runReport(item, hook, on: torrent, files: files, held: held) }
            }
        }
    }

    private func runReport(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on torrent: Torrent,
                           files: [TorrentFile], held: Bool) async {
        let previous = checks.record("\(item.name)/\(hook.name)", for: torrent.hash)
        let download = report(on: torrent, files: files, seen: previous?.seenFiles ?? [], held: held)
        let record = await run(item, hook, on: download, limited: true)
        if record.notify == true { onNotice?(torrent.hash, torrent.name, record) }
    }

    /// The download as a report sees it: with the other checks' results, and
    /// once it's finished, its files, those it hasn't `seen` marked new.
    private func report(on torrent: Torrent, files: [TorrentFile], seen: [Int], held: Bool) -> ExtensionDownload {
        let finished = torrent.isComplete && !held
        var download = ExtensionDownload(torrent: torrent, files: files, includingFilesOnDisk: finished)
        if finished { download.newFiles = Set(download.onDisk.keys).subtracting(seen) }
        download.checks = checks.records(for: torrent.hash).filter { $0.event != .afterChecks && $0.status.isFinished }
        download.isHeld = held
        return download
    }

    // MARK: Running

    /// Runs a hook again, or for the first time, on a download in the library.
    @discardableResult
    func runAgain(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on torrent: Torrent) async -> CheckRecord? {
        guard let files = try? await self.files?(torrent.hash) else { return nil }
        // Run by hand, every file is new to it again.
        let download: ExtensionDownload
        switch hook.event {
        case .beforeStart:
            download = ExtensionDownload(torrent: torrent, files: files, includingFilesOnDisk: false)
        case .afterFinish:
            var finished = ExtensionDownload(torrent: torrent, files: files, includingFilesOnDisk: torrent.isComplete)
            if torrent.isComplete { finished.newFiles = Set(finished.onDisk.keys) }
            download = finished
        case .afterChecks:
            download = report(on: torrent, files: files, seen: [], held: checks.gate(for: torrent.hash) == .held)
        }
        let record = await run(item, hook, on: download, limited: hook.event != .beforeStart)
        if record.notify == true { onNotice?(torrent.hash, torrent.name, record) }
        // A held download that now passes its checks can start.
        if hook.event == .beforeStart, checks.gate(for: torrent.hash) == .held,
           !checks.records(for: torrent.hash).contains(where: { $0.event == .beforeStart && $0.status == .failed }) {
            await downloadAnyway(torrent.hash)
        }
        return record
    }

    /// Runs one hook on a download as it's given, such as for `orb run`.
    func run(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on download: ExtensionDownload) async -> CheckRecord {
        let record = await run(item, hook, on: download, limited: hook.event != .beforeStart)
        if record.notify == true { onNotice?(download.id, download.name, record) }
        return record
    }

    /// Whether the user can run a hook on a download now: one after it
    /// finishes needs its files, and a report needs checks to report on.
    func canRun(_ hook: ExtensionManifest.Hook, on torrent: Torrent) -> Bool {
        switch hook.event {
        case .beforeStart: true
        case .afterFinish: torrent.isComplete
        case .afterChecks: torrent.isComplete || checks.gate(for: torrent.hash) == .held
        }
    }

    private func run(_ item: InstalledExtension, _ hook: ExtensionManifest.Hook, on download: ExtensionDownload,
                     limited: Bool) async -> CheckRecord {
        let key = "\(download.id)/\(item.name)/\(hook.name)"
        runs[key]?.cancel()
        var queued = CheckRecord(extension: item, hook: hook, status: limited ? .queued : .running, summary: "Waiting to run")
        queued.startedAt = .now
        // What it added and found before stays in view while it waits.
        let earlier = checks.record(queued.id, for: download.id)
        queued.addedFiles = earlier?.addedFiles
        queued.files = earlier?.files
        queued.seenFiles = earlier?.seenFiles
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
        let earlier = checks.record(record.id, for: download.id)
        // Files it added to this download before, which it may replace.
        let previouslyAdded = earlier?.addedFiles ?? []
        record.addedFiles = previouslyAdded.isEmpty ? nil : previouslyAdded
        record.files = earlier?.files
        record.seenFiles = earlier?.seenFiles
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
        let adder = ExtensionFileAdder(folder: download.folder, files: download.onDisk,
                                       allowed: item.manifest.permissions.addsFiles, replaceable: Set(previouslyAdded))
        var services = ExtensionServices(
            network: ExtensionNetwork(extensionName: item.name, permissions: item.manifest.permissions),
            files: download.onDisk, storage: storage(for: item.name), secrets: resolved.secrets,
            onProgress: { [weak self] progress in
                Task { @MainActor in
                    self?.checks.change(recordID, for: download.id) { $0.progress = progress }
                    self?.emit(.progress(name: item.name, hash: download.id, download: download.name, hook: hook.name, progress: progress))
                }
            },
            onLog: logger(for: item, entryPoint: hook.name, download: download.name))
        services.adder = adder
        let outcome = await runner.run(job, handler: services)
        // What it added stays listed, however the run ended.
        let added = previouslyAdded + (await adder.added).filter { !previouslyAdded.contains($0) }
        record.addedFiles = added.isEmpty ? nil : added
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
            finished.notify = value["notify"]?.bool == true ? true : nil
            finished.link = Self.link(value["link"])
            let files: [CheckRecord.FileResult]
            do {
                files = try Self.fileResults(value["files"], of: download)
            } catch {
                return finish(record, .didNotFinish, error.message, on: download)
            }
            finished.files = files.isEmpty ? nil : files
            // A result is never better than its worst file.
            var shown = status
            if let worst = files.first, worst.status.rank < status.rank {
                shown = worst.status
                logs.append(ExtensionLogEntry(date: .now, level: "warn",
                                              message: "Its result said “\(status.rawValue)”, but \(worst.name) is “\(worst.status.rawValue)”, so it shows as \(worst.status.rawValue).",
                                              entryPoint: entryPoint, download: download.name), for: item.name)
            }
            // The files it has now seen, so the next run can say which are new.
            if download.newFiles != nil { finished.seenFiles = download.onDisk.keys.sorted() }
            let line = summary.replacingOccurrences(of: "\n", with: " ")
            return finish(finished, shown, String(line.prefix(300)), on: download, keepsFiles: true)
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

    /// Ends a run. What it found about files belongs to a result it
    /// returned, so a run that ends any other way drops what was found before.
    private func finish(_ record: CheckRecord, _ status: CheckRecord.Status, _ summary: String, on download: ExtensionDownload,
                        keepsFiles: Bool = false) -> CheckRecord {
        var finished = record
        finished.status = status
        finished.summary = summary
        finished.progress = nil
        finished.finishedAt = .now
        if !keepsFiles { finished.files = nil }
        checks.update(finished, for: download.id)
        emit(.check(name: record.extensionName, hash: download.id, download: download.name, record: finished))
        return finished
    }

    /// A result's link, if it's a web address.
    private static func link(_ value: JSONValue?) -> CheckRecord.Link? {
        guard let title = value?["title"]?.string, let text = value?["url"]?.string,
              let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return CheckRecord.Link(title: String(title.prefix(60)), url: url)
    }

    /// The most files a result can say something about. Problems come first,
    /// so it's passed files that are left out.
    static let maximumFileResults = 1_000

    /// What a result says about the download's files, problems first, one
    /// for each file, the worst if it names one twice.
    static func fileResults(_ value: JSONValue?, of download: ExtensionDownload) throws(ExtensionRefusal) -> [CheckRecord.FileResult] {
        guard let value, !value.isNull else { return [] }
        guard let list = value.array else {
            throw ExtensionRefusal(message: "Its result's “files” isn't a list. Return files: [{ file, status, summary }].")
        }
        var paths: [Int: String] = [:]
        for file in download.files where paths[file.index] == nil { paths[file.index] = file.path }
        var results: [Int: CheckRecord.FileResult] = [:]
        for entry in list {
            // A file from download.files, or its index.
            let file = entry["file"]
            guard let index = file?.int ?? file?["index"]?.int, let path = paths[index] else {
                throw ExtensionRefusal(message: "Its result's “files” names a file that isn't part of this download. Pass a file from download.files, or its index.")
            }
            guard let status = entry["status"]?.string.flatMap(CheckRecord.Status.init(rawValue:)),
                  [.passed, .warning, .failed].contains(status) else {
                let name = (path as NSString).lastPathComponent
                throw ExtensionRefusal(message: "Its result gives \(name) a status that isn't “passed”, “warning” or “failed”.")
            }
            let summary = (entry["summary"]?.string ?? "").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            let result = CheckRecord.FileResult(index: index, path: path, status: status,
                                                summary: summary.isEmpty ? nil : String(summary.prefix(300)),
                                                link: link(entry["link"]))
            if let existing = results[index], existing.status.rank <= status.rank { continue }
            results[index] = result
        }
        let sorted = results.values.sorted { ($0.status.rank, $0.index) < ($1.status.rank, $1.index) }
        return Array(sorted.prefix(maximumFileResults))
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
