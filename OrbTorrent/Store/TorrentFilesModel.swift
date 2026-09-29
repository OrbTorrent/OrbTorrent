import Foundation
import Observation

/// The live file list of one download and the actions that change it.
///
/// Shared by the inspector's Files tab and the menu bar panel. Priority changes
/// show immediately and are sent to the engine in one batch per priority, so
/// toggling many files at once costs a single request.
@MainActor
@Observable
final class TorrentFilesModel {
    private(set) var hash: String?
    private(set) var files: [TorrentFile] = []
    private(set) var hasLoaded = false
    private(set) var loadError: String?

    @ObservationIgnored private let store: TorrentStore
    @ObservationIgnored private var pending: [Int: FilePriority] = [:]
    @ObservationIgnored private var flushTask: Task<Void, Never>?

    init(store: TorrentStore) {
        self.store = store
    }

    private var orders: DownloadOrderManager { store.orders }

    // MARK: Loading

    /// Keeps the list current for as long as the calling task runs.
    func track(_ hash: String) async {
        if hash != self.hash {
            self.hash = hash
            files = []
            hasLoaded = false
            loadError = nil
        }
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: .seconds(1.5))
        }
    }

    func refresh() async {
        guard let hash else { return }
        do {
            let latest = try await store.files(of: hash)
            // Don't let a poll that raced a local change undo it.
            guard flushTask == nil, hash == self.hash else { return }
            if latest != files { files = latest }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        hasLoaded = true
    }

    // MARK: Derived state

    var isOrdering: Bool { hash.map(orders.isOrdered) ?? false }

    /// Files in download order when ordering, otherwise by name.
    var displayedFiles: [TorrentFile] {
        guard let hash else { return files }
        return isOrdering
            ? orders.ordered(files, for: hash)
            : files.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func position(of file: TorrentFile) -> Int? {
        guard let hash, isOrdering else { return nil }
        return orders.position(of: file, in: files, hash: hash)
    }

    var wantedCount: Int { files.count(where: \.isWanted) }

    /// Whether every file is on disk, leaving nothing to choose or order.
    var isAllDownloaded: Bool { !files.isEmpty && files.allSatisfy { $0.isWanted && $0.isComplete } }

    /// Whether any chosen file is still downloading.
    var hasFilesLeft: Bool { files.contains { $0.isWanted && !$0.isComplete } }

    /// Whether ordering would change anything: at least two wanted files still downloading.
    var canOrder: Bool { files.count(where: { $0.isWanted && !$0.isComplete }) >= 2 }

    /// "11 files · 129.3 MB", or "3 of 11 files · 42 MB" when some are skipped.
    var summary: String {
        guard !files.isEmpty else { return "" }
        let size = files.filter(\.isWanted).reduce(Int64(0)) { $0 + $1.size }
        let selection = wantedCount == files.count ? "" : "\(wantedCount) of "
        return "\(selection)\(Format.count(files.count, "file")) · \(Format.bytes(size))"
    }

    // MARK: Actions

    func setWanted(_ wanted: Bool, for targets: [TorrentFile]) {
        setPriority(wanted ? .normal : .skip, for: targets.filter { $0.isWanted != wanted })
    }

    func setAllWanted(_ wanted: Bool) {
        setWanted(wanted, for: files)
    }

    func setPriority(_ priority: FilePriority, for targets: [TorrentFile]) {
        guard !targets.isEmpty else { return }
        let indices = Set(targets.map(\.index))
        files = files.map { indices.contains($0.index) ? $0.with(priority: priority) : $0 }
        for index in indices { pending[index] = priority }
        if flushTask == nil {
            flushTask = Task { [weak self] in
                // Let a burst of changes from one gesture collect first.
                await Task.yield()
                await self?.flush()
            }
        }
    }

    private func flush() async {
        guard let hash else { return }
        let changes = pending
        pending = [:]
        let byPriority = Dictionary(grouping: changes.keys, by: { changes[$0]! })
        let snapshot = files
        for (priority, indices) in byPriority {
            let targets = snapshot.filter { indices.contains($0.index) }
            await store.setPriority(priority, of: targets, in: hash)
        }
        flushTask = nil
        if !pending.isEmpty {
            flushTask = Task { [weak self] in await self?.flush() }
        }
    }

    func setOrdering(_ enabled: Bool) {
        guard let hash else { return }
        if enabled {
            orders.enable(for: hash, files: files)
            applyOrder()
        } else {
            orders.disable(for: hash)
            // Hand control back to the person: reset the automatic priorities.
            setPriority(.normal, for: files.filter { $0.isWanted && $0.priority != .normal })
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        guard let hash else { return }
        orders.move(in: hash, files: files, from: source, to: destination)
        applyOrder()
    }

    func downloadNext(_ file: TorrentFile) {
        guard let hash else { return }
        orders.moveToFront(file.index, in: hash, files: files)
        applyOrder()
    }

    /// Gives files their place-in-line priorities straight away, rather than
    /// waiting for the store's next pass, so the circles update as you drop.
    private func applyOrder() {
        guard let hash else { return }
        let desired = orders.desiredPriorities(for: files, hash: hash)
        for priority in [FilePriority.maximum, .high, .normal] {
            setPriority(priority, for: files.filter { desired[$0.index] == priority && $0.priority != priority })
        }
    }
}
