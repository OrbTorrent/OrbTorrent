import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

/// Owns OrbTorrent's long-lived services and coordinates app-wide flows.
@MainActor
@Observable
final class AppModel {
    let settings = AppSettings()
    let engine = EngineController()
    let orders = DownloadOrderManager()
    let trackerList = TrackerList()
    let defaultApp = DefaultAppManager()
    let loginItem = LoginItemManager()
    let store: TorrentStore
    let adder: AddTorrentCoordinator
    let vpn: VPNBinding
    let extensions = Extensions()
    @ObservationIgnored let notifier = CompletionNotifier()
    @ObservationIgnored let developmentServer: DevelopmentServer

    /// The engine's own settings, loaded once it is running.
    private(set) var preferences: EnginePreferences?
    var isInspectorPresented = true
    /// Whether the main window shows the library or the Extensions page.
    var section = MainSection.library
    /// The extensions opened on the Extensions page, by name.
    var extensionPath: [String] = []
    var extensionsTab = ExtensionsTab.installed
    var activityFilter = ActivityFilter()
    var extensionSearch = ""
    var isWelcomePresented = false
    /// The app whose downloads and settings are being brought over.
    var importSource: ImportSource?
    /// Downloads awaiting the "Remove" confirmation.
    var removalCandidates: [Torrent] = []
    var isRemovalConfirmationPresented = false

    /// Opens (or focuses) the main window. Registered by SwiftUI views that
    /// have access to `openWindow`; requests made earlier wait for it.
    @ObservationIgnored private var openMainWindow: (() -> Void)?
    @ObservationIgnored private var wantsMainWindow = false
    @ObservationIgnored private var hasLaunched = false

    func registerWindowOpener(_ opener: @escaping () -> Void) {
        openMainWindow = opener
        if wantsMainWindow {
            wantsMainWindow = false
            opener()
            NSApp.activate()
        }
    }

    init() {
        store = TorrentStore(engine: engine, orders: orders, trackerList: trackerList, notifier: notifier, settings: settings)
        adder = AddTorrentCoordinator(store: store, settings: settings, extensions: extensions)
        vpn = VPNBinding(settings: settings, engine: engine)
        developmentServer = DevelopmentServer(extensions: extensions)
        engine.networkInterface = { [weak self] in self?.vpn.interfaceForLaunch ?? "" }
        engine.didStart = { [weak self] in await self?.engineDidStart() }
        vpn.reconnectPeers = { [weak self] in await self?.store.reconnectPeers() }
        vpn.ports.onEngineSettingsChanged = { [weak self] in Task { await self?.reloadPreferences() } }
        adder.reveal = { [weak self] hash in self?.showMainWindow(selecting: hash) }
        adder.defaultSavePath = { [weak self] in self?.preferences?.savePath }
        adder.installExtension = { [weak self] url in self?.requestInstall(from: url) }
        notifier.onAction = { [weak self] action, hash in self?.handleNotification(action, hash: hash) }
        connectExtensions()
    }

    private func connectExtensions() {
        let engine = engine
        extensions.files = { hash in try await engine.client.files(of: hash) }
        extensions.start = { [weak self] hashes in await self?.store.resume(hashes) }
        extensions.onHeld = { [weak self] torrent, records in self?.notifier.postHeld(torrent, by: records) }
        extensions.onFlagged = { [weak self] torrent, record in self?.notifier.postFound(torrent, record) }
        store.didRefresh = { [weak self] torrents in self?.extensions.observe(torrents) }
        store.statusOverride = { [weak self] torrent in self?.checkStatus(of: torrent) }
        store.statusActivity = { [weak self] torrent in self?.checkActivity(of: torrent) }
        developmentServer.torrents = { [weak self] in self?.store.torrents ?? [] }
        developmentServer.confirmLoading = { [weak self] item, folder in self?.confirmDevelopmentLoad(item, from: folder) ?? false }
    }

    /// What a download's status line says while its checks hold it.
    private func checkStatus(of torrent: Torrent) -> String? {
        guard extensions.isOn else { return nil }
        switch extensions.checks.gate(for: torrent.hash) {
        case .waiting where torrent.hasMetadata, .checkOnly where torrent.hasMetadata:
            return "Checking before it starts…"
        case .held:
            let titles = extensions.checks.records(for: torrent.hash)
                .filter { $0.event == .beforeStart && $0.status == .failed }.map(\.extensionTitle)
            return titles.isEmpty ? "Held until you start it" : "Held by \(ListFormatter.localizedString(byJoining: titles))"
        default:
            return nil
        }
    }

    /// A check running on a download that isn't held up by it, such as a
    /// scan after it finished.
    private func checkActivity(of torrent: Torrent) -> String? {
        guard extensions.isOn else { return nil }
        let records = extensions.checks.records(for: torrent.hash)
        if let running = records.first(where: { $0.status == .running }) {
            if let done = running.progress?.done, let total = running.progress?.total, total > 0 {
                return "Checking with \(running.extensionTitle) · \(done) of \(total)"
            }
            return "Checking with \(running.extensionTitle)…"
        }
        if let queued = records.first(where: { $0.status == .queued }) {
            return "\(queued.extensionTitle) will check it next"
        }
        return nil
    }

    /// Shows the install sheet for an .orbext file or an extension's folder.
    /// While extensions are off, it asks to turn them on first.
    func requestInstall(from url: URL) {
        guard extensions.isOn || confirmTurningOnToInstall() else { return }
        do {
            extensions.installRequest = try extensions.registry.inspect(url)
        } catch {
            extensions.installError = error.localizedDescription
        }
        showExtensions()
    }

    /// Asks for an .orbext file or an extension's folder to install.
    func chooseExtensionToInstall() {
        let panel = NSOpenPanel()
        panel.title = "Install an Extension"
        panel.message = "Choose an .orbext file, or an extension's folder."
        panel.allowedContentTypes = [.orbExtension, .folder]
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        requestInstall(from: url)
    }

    /// Turns development extensions on or off, with the socket `orb` uses.
    func setAllowsDevelopmentExtensions(_ isOn: Bool) {
        extensions.registry.allowsDevelopment = isOn
        if isOn && extensions.isOn { developmentServer.start() } else { developmentServer.stop() }
    }

    /// Turns every extension off, so OrbTorrent is a plain torrent client, or
    /// back on. Before letting go of downloads that wait on checks, it asks.
    func setExtensionsOn(_ isOn: Bool) {
        guard isOn || confirmTurningOff() else { return }
        extensions.setOn(isOn)
        if isOn && extensions.registry.allowsDevelopment { developmentServer.start() }
        if !isOn {
            developmentServer.stop()
            extensionPath = []
        }
    }

    /// Says what happens to downloads waiting on checks, if there are any.
    private func confirmTurningOff() -> Bool {
        let gates = Array(extensions.checks.gated.values)
        let held = gates.filter { $0 == .held }.count
        let waiting = gates.filter { $0 == .waiting }.count
        guard held + waiting > 0 else { return true }
        var lines: [String] = []
        if held > 0 {
            lines.append(held == 1 ? "The download a check is holding stays paused, for you to start."
                                   : "The \(held) downloads checks are holding stay paused, for you to start.")
        }
        if waiting > 0 {
            lines.append(waiting == 1 ? "The download waiting for its checks starts now."
                                      : "The \(waiting) downloads waiting for their checks start now.")
        }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Turn off extensions?"
        alert.informativeText = lines.joined(separator: " ")
        alert.addButton(withTitle: "Turn Off")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Asks to turn extensions on, to install one while they're off.
    private func confirmTurningOnToInstall() -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Turn on extensions?"
        alert.informativeText = "Extensions are off, so OrbTorrent doesn't check downloads. Turn them on to install this one."
        alert.addButton(withTitle: "Turn On")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        setExtensionsOn(true)
        return true
    }

    /// Asks before loading an extension from a folder for the first time.
    private func confirmDevelopmentLoad(_ item: InstalledExtension, from folder: URL) -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Load “\(item.title)” for development?"
        let abilities = item.manifest.abilities.map { "• \($0)" }.joined(separator: "\n")
        alert.informativeText = """
        From \(folder.path)

        It isn't reviewed by OrbTorrent. It can:
        \(abilities)

        Only allow an extension you're building or trust.
        """
        if let icon = item.iconURL.flatMap(NSImage.init(contentsOf:)) { alert.icon = icon }
        alert.addButton(withTitle: "Load")
        alert.addButton(withTitle: "Don't Load")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// What the menu bar panel and the sidebar say is wrong, if anything.
    var problem: StatusProblem? {
        switch engine.status {
        case .starting: nil
        case .stopped, .failed: .connection(.engineOffline)
        case .running:
            StatusProblem.current(fullDisks: store.fullDisks, vpn: vpn.status,
                                  vpnName: settings.vpnServiceID.flatMap { id in vpn.monitor.services.first { $0.id == id }?.name },
                                  connection: store.connectionProblem)
        }
    }

    // MARK: Lifecycle

    func launch() async {
        guard !hasLaunched else { return }
        hasLaunched = true
        defaultApp.refresh()
        if settings.notifyOnCompletion { notifier.requestAuthorization() }
        trackerList.start { [weak self] in self?.settings.findMorePeers ?? false }
        if extensions.isOn && extensions.registry.allowsDevelopment { developmentServer.start() }
        if !settings.hasCompletedOnboarding {
            isWelcomePresented = true
            showMainWindow()
        }
        await startEngine()
    }

    func startEngine() async {
        await engine.start()
        guard engine.isRunning else { return }
        store.startPolling()
    }

    func restartEngine() async {
        store.stopPolling()
        await engine.restart()
        if engine.isRunning { store.startPolling() }
    }

    /// Sets the engine up each time it starts, including when it starts again
    /// by itself after stopping unexpectedly.
    private func engineDidStart() async {
        await vpn.engineDidStart()
        await applyFirstRunDefaults()
        // The engine refreshes what it reports every 1.5 s by default, so a
        // pause, a resume or a new speed could take that long to show.
        try? await engine.client.setPreferences(["refresh_interval": .int(500)])
        await reloadPreferences()
    }

    /// Stops the engine cleanly. Called when OrbTorrent quits.
    func shutdown() async {
        developmentServer.stop()
        extensions.checks.saveNow()
        store.stopPolling()
        await engine.stop()
    }

    // MARK: Windows

    func showMainWindow(selecting hash: String? = nil) {
        MenuBarIcon.closePanel()
        if let hash {
            section = .library
            store.filter = .all
            store.searchText = ""
            store.selection = [hash]
            isInspectorPresented = true
        }
        // Open the window before activating: activating a menu bar app that
        // has no window makes SwiftUI open the menu bar panel instead.
        if let openMainWindow {
            openMainWindow()
            NSApp.activate()
        } else {
            wantsMainWindow = true
        }
    }

    /// Opens the Extensions page, or one extension's page.
    func showExtensions(_ name: String? = nil) {
        section = .extensions
        extensionsTab = .installed
        extensionPath = name.map { [$0] } ?? []
        showMainWindow()
    }

    /// Lists every check on the Activity tab, or one extension's.
    func showActivity(of name: String? = nil) {
        activityFilter = ActivityFilter(extensionName: name)
        extensionsTab = .activity
        extensionPath = []
    }

    /// Selects a download and shows its Checks tab, while extensions are on.
    func showChecks(of hash: String) {
        if extensions.isOn {
            UserDefaults.standard.set(TorrentInspectorView.Tab.checks.rawValue, forKey: "inspectorTab")
        }
        showMainWindow(selecting: hash)
    }

    func requestRemoval(of torrents: [Torrent]) {
        guard !torrents.isEmpty else { return }
        removalCandidates = torrents
        isRemovalConfirmationPresented = true
        showMainWindow()
    }

    /// Removes the downloads asked about, deleting their files too if asked,
    /// the way the settings say.
    func confirmRemoval(deletingFiles: Bool) {
        let torrents = removalCandidates
        removalCandidates = []
        Task { await store.remove(torrents, files: deletingFiles ? deletedFiles : .keep) }
    }

    /// Removes downloads with their files, the way the settings say.
    func delete(_ torrents: [Torrent]) async {
        await store.remove(torrents, files: deletedFiles)
    }

    private var deletedFiles: TorrentStore.RemovedFiles {
        switch settings.deleteBehavior {
        case .moveToTrash: .trash
        case .deletePermanently: .erase
        }
    }

    private func handleNotification(_ action: CompletionNotifier.Action, hash: String) {
        guard let torrent = store.torrent(hash) else { return }
        switch action {
        case .show: showMainWindow(selecting: hash)
        case .open: FileActions.open(torrent)
        case .reveal: FileActions.reveal(torrent)
        case .showChecks: showChecks(of: hash)
        case .downloadAnyway: Task { await extensions.downloadAnyway(hash) }
        case .remove: requestRemoval(of: [torrent])
        }
    }

    // MARK: Engine preferences

    func reloadPreferences() async {
        preferences = try? await engine.client.preferences()
    }

    func updatePreferences(_ values: [String: PreferenceValue]) async {
        do {
            if case .int(let port)? = values["listen_port"], port != preferences.map({ Int64($0.listenPort) }) {
                try await engine.changeListening(values)
            } else {
                try await engine.client.setPreferences(values)
            }
        } catch let error where !error.isCancellation {
            store.actionError = error.localizedDescription
        } catch {}
        await reloadPreferences()
    }

    /// Transmission-like defaults, applied the first time the engine runs.
    private func applyFirstRunDefaults() async {
        guard !settings.appliedEngineDefaults else { return }
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Downloads").path
        do {
            try await engine.client.setPreferences([
                "save_path": .string(downloads),
                "temp_path_enabled": .bool(false),
                "queueing_enabled": .bool(false),
                "add_stopped_enabled": .bool(false),
                "torrent_content_layout": .string("Original"),
                "incomplete_files_ext": .bool(false),
                "preallocate_all": .bool(false),
                "up_limit": .int(5_000 * 1_024),
                "dl_limit": .int(0),
                "upnp": .bool(true),
                "dht": .bool(true),
                "pex": .bool(true),
                "lsd": .bool(true),
                "bittorrent_protocol": .int(0),
            ])
            settings.appliedEngineDefaults = true
        } catch {
            // Retried on the next launch.
        }
    }

    // MARK: Import

    /// Apps on this Mac with downloads or settings to bring over.
    var importSources: [ImportSource] {
        ImportSource.allCases.filter(\.hasLibrary)
    }

    func showImport(from source: ImportSource) {
        importSource = source
        showMainWindow()
    }

    /// The downloads OrbTorrent has, which an import leaves out.
    private var knownHashes: Set<String> {
        let saved = (try? FileManager.default.contentsOfDirectory(atPath: EnginePaths.resumeDirectory.path)) ?? []
        return Set(saved.map { String($0.prefix { $0 != "." }) }).union(store.torrents.map(\.hash))
    }

    /// What another app has for OrbTorrent, read away from the main thread.
    func importPlan(from source: ImportSource) async -> ImportPlan {
        let existing = knownHashes
        return await Task.detached { source.plan(excluding: existing) }.value
    }

    /// The plan's settings that differ from OrbTorrent's. While a VPN's
    /// forwarded port is in use, the listening port is left to it.
    func importableSettings(in plan: ImportPlan) -> [ImportedSetting] {
        guard let preferences else { return [] }
        let changes = plan.settings.changes(from: preferences)
        guard case .forwarded = vpn.ports.status else { return changes }
        return changes.filter { !$0.isAboutPort }
    }

    /// What each app on this Mac has to bring over. Settings are left out
    /// until the engine reports its own to compare them with.
    func importFindings() async -> [ImportFinding] {
        var findings: [ImportFinding] = []
        for source in importSources {
            let plan = await importPlan(from: source)
            let settings = importableSettings(in: plan)
            guard !plan.downloads.isEmpty || !settings.isEmpty else { continue }
            findings.append(ImportFinding(source: source, downloads: plan.downloads.count,
                                          settings: settings, lastUsed: source.lastUsed))
        }
        return findings
    }

    /// Brings over another app's downloads and the chosen settings, and
    /// returns how many downloads came over.
    func runImport(from source: ImportSource, includingDownloads: Bool, settings: [ImportedSetting]) async throws -> Int {
        let imported = try await runImport([ImportJob(source: source, includesDownloads: includingDownloads, settings: settings)])
        return imported[source] ?? 0
    }

    /// Brings over each app's downloads and settings, and returns how many
    /// downloads came over from each. The apps quit first, saving the latest
    /// state of their downloads as they do.
    func runImport(_ jobs: [ImportJob]) async throws -> [ImportSource: Int] {
        for job in jobs where job.source.isRunning {
            if !(await job.source.quit()) { throw ImportError.stillOpen(job.source) }
        }
        var plans: [(source: ImportSource, plan: ImportPlan)] = []
        for job in jobs where job.includesDownloads {
            let plan = await importPlan(from: job.source)
            if !plan.downloads.isEmpty { plans.append((job.source, plan)) }
        }
        var imported: [ImportSource: Int] = [:]
        if !plans.isEmpty {
            // The engine reads its downloads when it starts.
            store.stopPolling()
            await engine.stop()
            let result = await Task.detached { [plans] in
                // A download both apps have comes over once, from the first.
                Result {
                    try plans.reduce(into: [ImportSource: Int]()) { counts, item in
                        counts[item.source] = try ImportWriter.write(item.plan.downloads, categories: item.plan.categories)
                    }
                }
            }.value
            await startEngine()
            imported = try result.get()
        }
        let settings = jobs.flatMap(\.settings)
        if !settings.isEmpty {
            await updatePreferences(settings.reduce(into: [:]) { $0.merge($1.preferences) { $1 } })
        }
        return imported
    }
}
