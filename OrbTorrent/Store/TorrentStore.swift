import Foundation
import Observation
import SwiftUI

/// The live list of torrents and every action that changes them.
@MainActor
@Observable
final class TorrentStore {
    private(set) var torrents: [Torrent] = []
    private(set) var transfer: TransferInfo = .zero
    private(set) var hasLoaded = false
    /// Downloads receiving data now or within the last minute. A download
    /// often stalls for a few seconds as peers come and go, and the orb
    /// shouldn't flicker with it.
    private(set) var movingDownloads: Set<String> = []
    /// What's keeping the network from working well, if anything.
    private(set) var connectionProblem: ConnectionProblem?
    /// Downloads paused until their disk has room.
    private(set) var waitingForSpace: Set<String> = []
    /// The disks those downloads are waiting on, by name.
    private(set) var fullDisks: [String] = []
    /// An error from the last action, shown to the user once.
    var actionError: String?

    var selection: Set<String> = []
    var filter: SidebarFilter = .all
    var searchText = ""
    var sort: TorrentSort = .dateAdded

    let engine: EngineController
    let orders: DownloadOrderManager
    let trackerList: TrackerList
    let extraTrackers = ExtraTrackers()
    private let notifier: CompletionNotifier
    private let settings: AppSettings
    private var client: QBittorrentClient { engine.client }

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    /// Held while something is downloading, so the Mac doesn't idle-sleep.
    @ObservationIgnored private var sleepAssertion: NSObjectProtocol?
    /// When each download last received data.
    @ObservationIgnored private var lastReceived: [String: Date] = [:]
    /// How long a stalled download still counts as moving.
    private static let stallGrace: TimeInterval = 60
    /// The engine's last connection status, and when it began reporting it.
    @ObservationIgnored private var lastConnectionStatus: TransferInfo.ConnectionStatus?
    @ObservationIgnored private var connectionStatusSince: Date?
    /// Pauses and resumes shown before the engine reports them.
    @ObservationIgnored private var requestedStates = RequestedStates()
    @ObservationIgnored private let diskGuard = DiskSpaceGuard()
    /// When free space is next checked; looking it up takes a moment.
    @ObservationIgnored private var nextDiskCheck = Date.distantPast
    @ObservationIgnored private var isFindingPeers = false
    /// Sees each refresh of the library, such as extensions' checks.
    @ObservationIgnored var didRefresh: (([Torrent]) -> Void)?
    /// What a download's status line says instead, such as while its checks hold it.
    @ObservationIgnored var statusOverride: ((Torrent) -> String?)?
    /// What's happening to a download besides downloading, such as a check
    /// running on it, put before its status line.
    @ObservationIgnored var statusActivity: ((Torrent) -> String?)?
    private static let diskCheckInterval: TimeInterval = 5

    init(engine: EngineController, orders: DownloadOrderManager, trackerList: TrackerList,
         notifier: CompletionNotifier, settings: AppSettings) {
        self.engine = engine
        self.orders = orders
        self.trackerList = trackerList
        self.notifier = notifier
        self.settings = settings
        waitingForSpace = diskGuard.waiting
    }

    // MARK: Derived state

    var visibleTorrents: [Torrent] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return torrents
            .filter { filter.includes($0) && (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) }
            .sorted(by: sort.areInIncreasingOrder)
    }

    func count(for filter: SidebarFilter) -> Int {
        torrents.reduce(0) { $0 + (filter.includes($1) ? 1 : 0) }
    }

    func torrent(_ hash: String) -> Torrent? {
        torrents.first { $0.hash == hash }
    }

    var selectedTorrents: [Torrent] {
        torrents.filter { selection.contains($0.hash) }
    }

    /// Torrents worth showing in the menu bar: running downloads fastest first,
    /// then paused ones (so they can be resumed from there), then recently
    /// completed ones.
    var menuBarTorrents: [Torrent] {
        let unfinished = torrents.filter { !$0.isComplete }
        let active = unfinished
            .filter { !$0.state.isStopped }
            .sorted { ($0.downloadSpeed, $0.progress) > ($1.downloadSpeed, $1.progress) }
        let paused = unfinished
            .filter { $0.state.isStopped }
            .sorted { ($0.addedOn ?? .distantPast) > ($1.addedOn ?? .distantPast) }
        let finished = torrents
            .filter { $0.isComplete }
            .sorted { ($0.completedOn ?? .distantPast) > ($1.completedOn ?? .distantPast) }
        return Array((active + paused + finished).prefix(6))
    }

    var allStopped: Bool {
        !torrents.isEmpty && torrents.allSatisfy { $0.state.isStopped }
    }

    /// What a download is doing, saying so when it waits for disk space.
    func statusLine(of torrent: Torrent) -> String {
        if let override = statusOverride?(torrent) { return override }
        let line = torrent.statusLine(waitingForSpace: waitingForSpace.contains(torrent.hash))
        guard let activity = statusActivity?(torrent) else { return line }
        return "\(activity) · \(line)"
    }

    /// Unfinished downloads that are running or will resume by themselves,
    /// for counting the space they still need.
    var unfinishedDownloads: [DiskSpace.Download] {
        torrents
            .filter { !$0.isComplete && (!$0.state.isStopped || waitingForSpace.contains($0.hash)) }
            .map { DiskSpace.Download(savePath: $0.savePath, remaining: $0.amountLeft) }
    }

    // MARK: Polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
        updateSleepAssertion(downloading: false)
    }

    private func updateSleepAssertion(downloading: Bool) {
        let shouldHold = downloading && settings.preventSleepWhileDownloading
        if shouldHold, sleepAssertion == nil {
            sleepAssertion = ProcessInfo.processInfo.beginActivity(
                options: [.idleSystemSleepDisabled, .suddenTerminationDisabled],
                reason: "Downloading torrents"
            )
        } else if !shouldHold, let assertion = sleepAssertion {
            ProcessInfo.processInfo.endActivity(assertion)
            sleepAssertion = nil
        }
    }

    func refresh() async {
        guard engine.isRunning else { return }
        do {
            async let list = client.torrents()
            async let info = client.transferInfo()
            let (reported, latestTransfer) = try await (list, info)
            let latest = requestedStates.apply(to: reported)
            if torrents != latest {
                if Set(torrents.map(\.hash)) == Set(latest.map(\.hash)) {
                    torrents = latest
                } else {
                    // Insert and remove rows without animation: animated row
                    // insertion during live updates leaves macOS lists mis-measured.
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { torrents = latest }
                }
            }
            if transfer != latestTransfer { transfer = latestTransfer }
            hasLoaded = true
            updateMovingDownloads(latest)
            updateConnectionProblem(latest, latestTransfer)
            updateSleepAssertion(downloading: latest.contains { torrent in
                switch torrent.state.activity {
                case .downloading, .stalled, .fetchingMetadata, .checking: true
                default: false
                }
            })

            let known = Set(latest.map(\.hash))
            if !selection.isSubset(of: known) { selection.formIntersection(known) }
            // Drop the download order of removed torrents, and of finished ones:
            // there's nothing left to order.
            let unfinished = Set(latest.filter { !$0.isComplete }.map(\.hash))
            orders.forget(orders.orders.keys.filter { !unfinished.contains($0) })

            notifier.observe(latest, enabled: settings.notifyOnCompletion)
            didRefresh?(latest)
            await applyDownloadOrders()
            await findMorePeers(latest)
            if Date.now >= nextDiskCheck {
                nextDiskCheck = .now.addingTimeInterval(Self.diskCheckInterval)
                await guardDiskSpace(latest)
            }
        } catch {
            // Transient while the engine restarts; the next tick retries.
        }
    }

    private func updateMovingDownloads(_ latest: [Torrent]) {
        let now = Date.now
        for torrent in latest where torrent.state.activity == .downloading {
            lastReceived[torrent.hash] = now
        }
        lastReceived = lastReceived.filter { now.timeIntervalSince($0.value) < Self.stallGrace }
        let moving = Set(latest.filter { torrent in
            lastReceived[torrent.hash] != nil && !torrent.isComplete && !torrent.state.isStopped
                && torrent.state.activity != .error
        }.map(\.hash))
        if moving != movingDownloads { movingDownloads = moving }
    }

    private func updateConnectionProblem(_ latest: [Torrent], _ transfer: TransferInfo) {
        if transfer.connectionStatus != lastConnectionStatus {
            lastConnectionStatus = transfer.connectionStatus
            connectionStatusSince = .now
        }
        let needsPeers = latest.contains { torrent in
            switch torrent.state.activity {
            case .downloading, .stalled, .fetchingMetadata: true
            default: false
            }
        }
        let problem = ConnectionProblem.current(status: transfer.connectionStatus,
                                                since: connectionStatusSince, needsPeers: needsPeers)
        if problem != connectionProblem { connectionProblem = problem }
    }

    /// Pauses downloads on a disk that's almost full, and resumes them once
    /// there's room again.
    private func guardDiskSpace(_ latest: [Torrent]) async {
        let paths = Set(latest.filter { !$0.isComplete }.map(\.savePath))
        let volumes = await Task.detached { DiskSpace.volumes(for: paths) }.value
        let decision = diskGuard.evaluate(latest, enabled: settings.pauseWhenDiskFull, volumes: volumes)
        if waitingForSpace != diskGuard.waiting { waitingForSpace = diskGuard.waiting }
        if fullDisks != decision.fullDisks { fullDisks = decision.fullDisks }
        if !decision.pause.isEmpty {
            await setStopped(true, decision.pause) { try await $0.stop(decision.pause) }
            notifier.postDiskAlmostFull(decision.fullDisks, paused: decision.pause.count)
        }
        if !decision.resume.isEmpty {
            await setStopped(false, decision.resume) { try await $0.start(decision.resume) }
        }
    }

    /// Re-assigns priorities for torrents whose files download in a set order.
    private func applyDownloadOrders() async {
        for hash in orders.orders.keys {
            guard let torrent = torrent(hash), !torrent.isComplete,
                  let files = try? await client.files(of: hash) else { continue }
            let desired = orders.desiredPriorities(for: files, hash: hash)
            var changes: [FilePriority: [Int]] = [:]
            for file in files {
                if let target = desired[file.index], target != file.priority {
                    changes[target, default: []].append(file.index)
                }
            }
            for (priority, indices) in changes {
                try? await client.setFilePriority(priority, files: indices, in: hash)
            }
        }
    }

    /// Adds the public tracker list to public torrents, and takes off what
    /// it added once that's no longer wanted.
    private func findMorePeers(_ latest: [Torrent]) async {
        // Refreshes can overlap, and the same trackers mustn't go on twice.
        guard !isFindingPeers else { return }
        isFindingPeers = true
        defer { isFindingPeers = false }
        let changes = extraTrackers.changes(for: latest, list: trackerList.trackers,
                                            revision: trackerList.revision, enabled: settings.findMorePeers)
        // A few at a time, so a large library doesn't hold up the refresh.
        for change in changes.prefix(10) {
            do {
                try await client.removeTrackers(change.remove, from: change.hash)
                if !change.add.isEmpty {
                    // After the torrent's own tiers, so it keeps announcing to its own trackers first.
                    let tiers = try await client.trackers(of: change.hash).filter { !$0.isPeerSource }.map(\.tier)
                    let firstTier = min((tiers.max() ?? -1) + 1, 256 - change.add.count)
                    try await client.addTrackers(change.add, to: change.hash, firstTier: firstTier)
                }
                extraTrackers.didApply(change)
            } catch {
                extraTrackers.didFail(change)
            }
        }
    }

    // MARK: Actions

    /// Resumes downloads, except those waiting for disk space: they resume by
    /// themselves once there's room.
    func resume(_ hashes: [String]) async {
        let hashes = hashes.filter { !waitingForSpace.contains($0) }
        guard !hashes.isEmpty else { return }
        await setStopped(false, hashes) { try await $0.start(hashes) }
    }

    func pause(_ hashes: [String]) async {
        await setStopped(true, hashes) { try await $0.stop(hashes) }
    }

    func resumeAll() async {
        guard waitingForSpace.isEmpty else {
            await resume(torrents.filter(\.state.isStopped).map(\.hash))
            return
        }
        await setStopped(false, torrents.map(\.hash)) { try await $0.start([]) }
    }

    func pauseAll() async {
        await setStopped(true, torrents.map(\.hash)) { try await $0.stop([]) }
    }

    /// Drops every connection to peers by pausing and resuming the downloads
    /// that have any. They're shown running throughout, as the pause is only
    /// a moment.
    func reconnectPeers() async {
        let connected = ((try? await client.torrents()) ?? torrents).filter(\.state.mayHavePeers)
        // An empty list would mean every download to the engine.
        guard !connected.isEmpty else { return }
        let hashes = connected.map(\.hash)
        requestedStates.request(stopped: false, for: hashes)
        try? await client.stop(hashes)
        try? await client.start(hashes)
        let forced = connected.filter(\.state.isForced).map(\.hash)
        if !forced.isEmpty { try? await client.forceStart(forced) }
        await refresh()
    }

    /// Pauses or resumes downloads, showing the change as soon as the engine
    /// accepts it rather than when it next reports it.
    private func setStopped(_ stopped: Bool, _ hashes: [String],
                            _ operation: (QBittorrentClient) async throws -> Void) async {
        do {
            try await operation(client)
        } catch {
            if !error.isCancellation { actionError = error.localizedDescription }
            return
        }
        requestedStates.request(stopped: stopped, for: hashes)
        torrents = requestedStates.apply(to: torrents)
        await refresh()
    }

    /// Pauses the selection if anything in it is running, otherwise resumes it.
    func togglePause(_ torrents: [Torrent]) async {
        let hashes = torrents.map(\.hash)
        if torrents.contains(where: { !$0.state.isStopped }) {
            await pause(hashes)
        } else {
            await resume(hashes)
        }
    }

    /// What happens to a removed download's files.
    enum RemovedFiles {
        /// Left where they are.
        case keep
        /// Moved to the Trash, so they can be put back.
        case trash
        /// Deleted by the engine at once; they can't be put back.
        case erase
    }

    func remove(_ torrents: [Torrent], files: RemovedFiles) async {
        guard !torrents.isEmpty else { return }
        let hashes = torrents.map(\.hash)
        var filesByHash: [String: [TorrentFile]] = [:]
        if files == .trash {
            for torrent in torrents {
                filesByHash[torrent.hash] = (try? await client.files(of: torrent.hash)) ?? []
            }
        }
        do {
            try await client.delete(hashes, deleteFiles: files == .erase)
        } catch {
            if !error.isCancellation { actionError = error.localizedDescription }
            return
        }
        selection.subtract(hashes)
        orders.forget(hashes)
        extraTrackers.forget(hashes)
        if files == .trash {
            // Give the engine a moment to close the files before moving them.
            try? await Task.sleep(for: .milliseconds(600))
            let failures = torrents.flatMap { FileActions.trashContent(of: $0, files: filesByHash[$0.hash] ?? []) }
            if let failure = failures.first {
                actionError = "Some files couldn't be moved to the Trash: \(failure.localizedDescription)"
            }
        }
        await refresh()
    }

    func recheck(_ hashes: [String]) async {
        await perform { try await $0.recheck(hashes) }
    }

    func reannounce(_ hashes: [String]) async {
        await perform { try await $0.reannounce(hashes) }
    }

    func toggleSequentialDownload(_ torrent: Torrent) async {
        await perform { try await $0.toggleSequentialDownload([torrent.hash]) }
    }

    func toggleFirstLastPiecePriority(_ torrent: Torrent) async {
        await perform { try await $0.toggleFirstLastPiecePriority([torrent.hash]) }
    }

    func move(_ torrents: [Torrent], to folder: URL) async {
        await perform { try await $0.setLocation(torrents.map(\.hash), to: folder.path) }
    }

    func setPriority(_ priority: FilePriority, of files: [TorrentFile], in hash: String) async {
        await perform { try await $0.setFilePriority(priority, files: files.map(\.index), in: hash) }
    }

    // MARK: Details

    func files(of hash: String) async throws -> [TorrentFile] {
        try await client.files(of: hash)
    }

    func peers(of hash: String) async throws -> [Peer] {
        try await client.peers(of: hash)
    }

    func trackers(of hash: String) async throws -> [Tracker] {
        try await client.trackers(of: hash)
    }

    func properties(of hash: String) async throws -> TorrentProperties {
        try await client.properties(of: hash)
    }

    private func perform(_ operation: (QBittorrentClient) async throws -> Void) async {
        do {
            try await operation(client)
            await refresh()
        } catch let error where !error.isCancellation {
            actionError = error.localizedDescription
        } catch {}
    }
}
