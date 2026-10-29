import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

/// Turns magnet links, `.torrent` files and pasted text into downloads.
@MainActor
@Observable
final class AddTorrentCoordinator {
    /// A torrent waiting for confirmation, in the window's sheet or the menu bar panel.
    struct Pending: Identifiable {
        enum Source {
            case magnet(MagnetLink)
            case file(data: Data, filename: String, metadata: TorrentMetadata)
        }

        let id = UUID()
        let source: Source
        var saveFolder: URL?
        var startImmediately = true
        var sequentialDownload = false
        /// File indices the person unticked, once the files are known.
        var skippedFiles: Set<Int> = []
        /// A magnet link's files, if its peers sent them while it was asked about.
        var fetchedMetadata: TorrentMetadata?
        /// Whether a magnet link's peers are being asked for its files.
        var isAskingPeers = false
        /// Public trackers added to a magnet link to look it up. The engine
        /// keeps them on the torrent when it's added with the files its peers sent.
        var lookupTrackers: [String] = []
        /// Extensions' checks before it starts, which run once its files are known.
        var checkState = CheckState.none

        enum CheckState {
            case none, checking, done
        }

        var name: String {
            switch source {
            case .magnet(let link): fetchedMetadata?.name ?? link.displayName ?? "Magnet Link"
            case .file(_, _, let metadata): metadata.name
            }
        }

        var infoHash: String? {
            switch source {
            case .magnet(let link): link.infoHash
            case .file(_, _, let metadata): metadata.infoHash
            }
        }

        var metadata: TorrentMetadata? {
            if case .file(_, _, let metadata) = source { return metadata }
            return fetchedMetadata
        }

        /// What the chosen files need on disk. Magnet links don't say until
        /// their peers send the files.
        var neededBytes: Int64? {
            metadata.map { $0.files.filter { !skippedFiles.contains($0.id) }.reduce(0) { $0 + $1.size } }
        }
    }

    /// Where a torrent is asked about, when the settings say to ask first.
    enum AskPlace {
        /// A sheet on the OrbTorrent window, for torrents added from it.
        case window
        /// The menu bar panel, for links and files opened from other apps.
        case menuBar
    }

    /// A torrent waiting for confirmation in the window's sheet.
    var pending: Pending?
    /// Torrents waiting for confirmation in the menu bar panel, oldest first.
    var menuBarQueue: [Pending] = []
    var isMagnetSheetPresented = false
    /// A short message such as "Already in your library", shown as a toast.
    var notice: String?
    var errorMessage: String?

    /// Shows the main window and selects a torrent.
    @ObservationIgnored var reveal: ((String?) -> Void)?
    /// Shows the panel that asks about the torrents in `menuBarQueue`.
    @ObservationIgnored var showMenuBarConfirmation: (() -> Void)?
    /// Shows the downloads in that panel, once a torrent asked about there is added.
    @ObservationIgnored var showMenuBarDownloads: (() -> Void)?
    /// The engine's save folder, once its settings are loaded.
    @ObservationIgnored var defaultSavePath: (() -> String?)?
    /// Offers to install an extension opened from Finder.
    @ObservationIgnored var installExtension: ((URL) -> Void)?

    private let store: TorrentStore
    private let settings: AppSettings
    private let extensions: Extensions

    init(store: TorrentStore, settings: AppSettings, extensions: Extensions) {
        self.store = store
        self.settings = settings
        self.extensions = extensions
    }

    // MARK: Entry points

    /// Handles URLs from Finder, the browser, drag and drop, or the open panel.
    func open(_ urls: [URL], askingIn place: AskPlace = .window) {
        for url in urls {
            if url.scheme?.lowercased() == "magnet" {
                handle(magnetText: url.absoluteString, askingIn: place)
            } else if url.isFileURL && url.pathExtension.lowercased() == "orbext" {
                installExtension?(url)
            } else if url.isFileURL {
                handle(fileAt: url, askingIn: place)
            } else if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                Task { await addRemote(url) }
            }
        }
    }

    /// Handles pasted or typed text containing a magnet link or a torrent URL.
    @discardableResult
    func add(text: String, askingIn place: AskPlace = .window) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let link = MagnetLink.first(in: trimmed) {
            handle(magnet: link, askingIn: place)
            return true
        }
        if let url = URL(string: trimmed), ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
            Task { await addRemote(url) }
            return true
        }
        return false
    }

    /// Returns a magnet link on the clipboard that isn't in the library yet.
    func clipboardMagnet() -> MagnetLink? {
        guard let text = NSPasteboard.general.string(forType: .string),
              let link = MagnetLink.first(in: text)
        else { return nil }
        if let hash = link.infoHash, store.torrent(hash) != nil { return nil }
        return link
    }

    func presentOpenPanel(askingIn place: AskPlace = .window) {
        let panel = NSOpenPanel()
        panel.title = "Open Torrent Files"
        panel.allowedContentTypes = [.torrent]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        NSApp.activate()
        if panel.runModal() == .OK {
            open(panel.urls, askingIn: place)
        }
    }

    func presentMagnetSheet() {
        reveal?(nil)
        isMagnetSheetPresented = true
    }

    // MARK: Handling

    private func handle(magnetText: String, askingIn place: AskPlace) {
        guard let link = MagnetLink(magnetText) else {
            errorMessage = "That magnet link isn't valid."
            return
        }
        handle(magnet: link, askingIn: place)
    }

    private func handle(magnet link: MagnetLink, askingIn place: AskPlace) {
        if let hash = link.infoHash, store.torrent(hash) != nil {
            alreadyAdded(hash)
            return
        }
        let pending = Pending(source: .magnet(link))
        if settings.addBehavior == .askFirst {
            ask(pending, in: place)
        } else {
            Task { await confirm(pending) }
        }
    }

    private func handle(fileAt url: URL, askingIn place: AskPlace) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            handle(fileData: try Data(contentsOf: url), filename: url.lastPathComponent, askingIn: place)
        } catch {
            errorMessage = "“\(url.lastPathComponent)” couldn't be opened. \(error.localizedDescription)"
        }
    }

    private func handle(fileData data: Data, filename: String, askingIn place: AskPlace) {
        do {
            let metadata = try TorrentMetadata(data: data)
            if store.torrent(metadata.infoHash) != nil {
                alreadyAdded(metadata.infoHash)
                return
            }
            let pending = Pending(source: .file(data: data, filename: filename, metadata: metadata))
            // One that won't fit is asked about even when downloads start right away.
            if settings.addBehavior == .askFirst || !fitsOnDisk(pending) {
                ask(pending, in: place)
            } else {
                Task { await confirm(pending) }
            }
        } catch {
            errorMessage = "“\(filename)” couldn't be opened. \(error.localizedDescription)"
        }
    }

    /// The folder a pending torrent will be saved to.
    func saveFolder(for pending: Pending) -> String {
        if let folder = pending.saveFolder { return folder.path }
        if let path = defaultSavePath?(), !path.isEmpty { return path }
        return NSString("~/Downloads").expandingTildeInPath
    }

    /// Whether a torrent fits on its disk alongside the unfinished downloads,
    /// as far as is known: magnet links don't say how big they are.
    private func fitsOnDisk(_ pending: Pending) -> Bool {
        guard let needed = pending.neededBytes,
              let room = DiskSpace.room(forFolder: saveFolder(for: pending), downloads: store.unfinishedDownloads)
        else { return true }
        return room.fits(needed)
    }

    private func ask(_ pending: Pending, in place: AskPlace) {
        guard place == .menuBar, let showMenuBarConfirmation else {
            show(pending)
            findFiles(of: pending)
            runChecks(of: pending.id)
            return
        }
        // Opening the same link twice asks about it once.
        let isWaiting = pending.infoHash.map { hash in menuBarQueue.contains { $0.infoHash == hash } } ?? false
        if !isWaiting {
            menuBarQueue.append(pending)
            findFiles(of: pending)
            runChecks(of: pending.id)
        }
        showMenuBarConfirmation()
    }

    /// Runs extensions' checks on a torrent being asked about, once its files
    /// are known, so their results show before it's added.
    private func runChecks(of id: Pending.ID) {
        guard extensions.hasBeforeStartHooks, let asked = asked(id), asked.checkState == .none,
              let metadata = asked.metadata else { return }
        change(id) { $0.checkState = .checking }
        extensions.beginAsking(metadata.infoHash)
        let download = ExtensionDownload(metadata: metadata, skipped: asked.skippedFiles)
        Task {
            _ = await extensions.runBeforeStart(on: download)
            change(id) { $0.checkState = .done }
        }
    }

    private func show(_ pending: Pending) {
        reveal?(nil)
        self.pending = pending
    }

    /// Asks a magnet link's peers for its files while the link is asked
    /// about, so its size and files can show before it's added. Once it's
    /// added, or cancelled, this stops asking; the engine keeps looking until
    /// it has the files or quits, then forgets them, saving nothing.
    private func findFiles(of asked: Pending) {
        guard case .magnet(let link) = asked.source else { return }
        let id = asked.id
        // More trackers help find its peers, unless it may be from a private tracker.
        let extra = settings.findMorePeers && link.trackers.allSatisfy(TrackerList.isPublic)
            ? store.trackerList.trackers.filter { !link.trackers.contains($0) } : []
        let source = link.adding(trackers: extra)
        change(id) {
            $0.isAskingPeers = true
            $0.lookupTrackers = extra
        }
        Task {
            while self.asked(id) != nil {
                guard await waitForEngine() else { break }
                do {
                    if let metadata = try await store.engine.client.metadata(ofMagnet: source) {
                        change(id) { $0.fetchedMetadata = metadata }
                        runChecks(of: id)
                        break
                    }
                } catch APIError.http {
                    // The engine can't look this link up.
                    break
                } catch {
                    // The engine may be restarting; it starts looking again once it's back.
                }
                try? await Task.sleep(for: .seconds(1))
            }
            change(id) { $0.isAskingPeers = false }
        }
    }

    /// A torrent still being asked about, as it stands now.
    func asked(_ id: Pending.ID) -> Pending? {
        if let pending, pending.id == id { return pending }
        return menuBarQueue.first { $0.id == id }
    }

    /// Changes a torrent that's still being asked about.
    func change(_ id: Pending.ID, _ body: (inout Pending) -> Void) {
        if pending?.id == id, var changed = pending {
            body(&changed)
            pending = changed
        }
        if let index = menuBarQueue.firstIndex(where: { $0.id == id }) {
            body(&menuBarQueue[index])
        }
    }

    /// Drops a torrent the menu bar panel asked about without adding it.
    func decline(_ pending: Pending) {
        menuBarQueue.removeAll { $0.id == pending.id }
        stopAsking(pending, added: false)
    }

    /// Drops the torrent the window's sheet asked about without adding it.
    func cancel(_ pending: Pending) {
        if self.pending?.id == pending.id { self.pending = nil }
        stopAsking(pending, added: false)
    }

    private func stopAsking(_ pending: Pending, added: Bool) {
        guard pending.checkState != .none, let hash = pending.metadata?.infoHash ?? pending.infoHash else { return }
        // The same torrent asked about somewhere else keeps its checks, and
        // so does one in the library, with any hold they put on it.
        if !added, askedAbout(hash, except: pending.id).contains(where: { $0.checkState != .none }) { return }
        extensions.endAsking(hash, added: added || store.torrent(hash) != nil)
    }

    /// The torrents with this info hash being asked about anywhere: in the
    /// window or the menu bar.
    private func askedAbout(_ hash: String, except other: Pending.ID? = nil) -> [Pending] {
        ([pending].compactMap { $0 } + menuBarQueue).filter { asked in
            asked.id != other && (asked.infoHash == hash || asked.metadata?.infoHash == hash)
        }
    }

    private func alreadyAdded(_ hash: String) {
        notice = "Already in your downloads"
        reveal?(hash)
    }

    // MARK: Adding

    /// Adds a pending torrent with the options chosen when asked (or defaults).
    func confirm(_ pending: Pending) async {
        let askedInMenuBar = menuBarQueue.contains { $0.id == pending.id }
        menuBarQueue.removeAll { $0.id == pending.id }
        if askedInMenuBar {
            showMenuBarDownloads?()
        }
        if self.pending?.id == pending.id {
            self.pending = nil
        }
        guard await waitForEngine() else {
            errorMessage = "The download engine isn't running, so the torrent couldn't be added."
            return
        }
        if let hash = pending.infoHash, store.torrent(hash) != nil {
            alreadyAdded(hash)
            return
        }
        let client = store.engine.client
        var options = QBittorrentClient.AddOptions()
        options.savePath = pending.saveFolder?.path
        options.sequentialDownload = pending.sequentialDownload
        // Torrents with unticked files start stopped so nothing unwanted is
        // fetched before the priorities are applied.
        let needsFilePriorities = !pending.skippedFiles.isEmpty
        // A private torrent found through public trackers loses them before
        // it starts, so it never announces to them.
        let dropsLookupTrackers = pending.metadata?.isPrivate == true && !pending.lookupTrackers.isEmpty
        options.startImmediately = pending.startImmediately && !needsFilePriorities && !dropsLookupTrackers
        // Checks that couldn't run while it was asked about run once its files
        // are known: the engine stops it then, before any data downloads.
        // One added stopped fetches its files too, then stays stopped once checked.
        let isGated = pending.checkState == .none && extensions.hasBeforeStartHooks
        if isGated {
            options.startImmediately = true
            options.stopsWhenFilesAreKnown = true
        }
        if let hash = pending.infoHash {
            store.extraTrackers.claim(pending.lookupTrackers, for: hash)
        }
        // Its checks are kept until it shows up in the library.
        let hash = pending.metadata?.infoHash ?? pending.infoHash
        let keepsChecks = hash != nil && (isGated || pending.checkState != .none)
        if keepsChecks, let hash {
            extensions.beginAsking(hash)
            if isGated { extensions.gate(hash, startsAfterChecks: pending.startImmediately) }
        }

        do {
            switch pending.source {
            case .magnet(let link):
                try await client.add(magnetOrURL: link.uri, options: options)
            case .file(let data, let filename, _):
                try await client.add(torrentFile: data, filename: filename, options: options)
            }
        } catch {
            if keepsChecks, let hash { extensions.endAsking(hash, added: false) }
            errorMessage = error.localizedDescription
            return
        }

        guard let hash else {
            await store.refresh()
            return
        }
        let appeared = await waitForTorrent(hash)
        if keepsChecks { extensions.endAsking(hash, added: appeared) }
        guard appeared else { return }

        if dropsLookupTrackers {
            try? await client.removeTrackers(pending.lookupTrackers, from: hash)
        }
        if needsFilePriorities, let metadata = pending.metadata {
            let skipped = metadata.files.filter { pending.skippedFiles.contains($0.id) }.map(\.id)
            try? await client.setFilePriority(.skip, files: skipped, in: hash)
        }
        if pending.startImmediately && (needsFilePriorities || dropsLookupTrackers) && !isGated {
            try? await client.start([hash])
        }
        await store.refresh()
        // Asked in the window, the window goes on to show the new download;
        // asked in the menu bar, the menu bar panel does.
        if !askedInMenuBar && (settings.openWindowOnAdd || settings.addBehavior == .askFirst) {
            reveal?(hash)
        }
    }

    private func addRemote(_ url: URL) async {
        // Checks need the torrent's files, so OrbTorrent fetches it itself.
        if extensions.hasBeforeStartHooks {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                guard (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false, data.count < 20 << 20 else {
                    throw URLError(.badServerResponse)
                }
                handle(fileData: data, filename: url.lastPathComponent, askingIn: .window)
            } catch {
                errorMessage = "The torrent at \(url.host() ?? url.absoluteString) couldn't be downloaded."
            }
            return
        }
        guard await waitForEngine() else {
            errorMessage = "The download engine isn't running, so the torrent couldn't be added."
            return
        }
        do {
            var options = QBittorrentClient.AddOptions()
            options.startImmediately = true
            try await store.engine.client.add(magnetOrURL: url.absoluteString, options: options)
            notice = "Downloading torrent file…"
            await store.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Links opened while OrbTorrent launches arrive before the engine is up; wait for
    /// it (and the first library load, for duplicate detection).
    private func waitForEngine() async -> Bool {
        let deadline = ContinuousClock.now + .seconds(60)
        while ContinuousClock.now < deadline {
            if store.engine.isRunning {
                if !store.hasLoaded { await store.refresh() }
                return true
            }
            if case .failed = store.engine.status { return false }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    /// Waits for a newly added torrent to show up in the engine's list.
    private func waitForTorrent(_ hash: String) async -> Bool {
        for _ in 0..<40 {
            await store.refresh()
            if store.torrent(hash) != nil { return true }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}

extension UTType {
    static let torrent = UTType(importedAs: "org.bittorrent.torrent")
}
