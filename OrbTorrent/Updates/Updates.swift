import AppKit
import Observation
import Sparkle

/// Keeps OrbTorrent up to date with Sparkle, from the feed in Info.plist,
/// and shows What's New after an update.
///
/// Sparkle's own window offers an update. One found while OrbTorrent is in
/// the background waits quietly instead, in the menu bar panel, the window
/// and a notification, until it's looked at.
///
/// OrbTorrent Dev doesn't update itself, except from a test feed made by
/// `scripts/publish-update.sh --test`:
///
///     defaults write com.orbtorrent.mac.dev UpdateFeedURL http://127.0.0.1:8123/appcast.xml
@MainActor
@Observable
final class Updates: NSObject {
    static let testFeedKey = "UpdateFeedURL"

    /// Whether this copy updates itself.
    private(set) var isEnabled = false
    /// False while a check or an update is already under way.
    private(set) var canCheck = false
    private(set) var lastCheck: Date?
    /// The name of a new version found in the background, such as
    /// "1.0 beta 3", until it's looked at.
    private(set) var waiting: String?

    var checksAutomatically = false {
        didSet { if isEnabled { updater.automaticallyChecksForUpdates = checksAutomatically } }
    }

    var downloadsAutomatically = false {
        didSet { if isEnabled { updater.automaticallyDownloadsUpdates = downloadsAutomatically } }
    }

    /// Releases to show in What's New, newest first.
    private(set) var whatsNew: [Release] = []
    var isWhatsNewPresented = false
    /// This version's notes, for the Help menu, once the feed has had them.
    private(set) var currentRelease: Release?

    /// Says a new version is waiting, or takes that back.
    @ObservationIgnored var onWaitingChange: ((String?) -> Void)?

    @ObservationIgnored let history = ReleaseHistory()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []
    private var updater: SPUUpdater { controller.updater }

    private static let seenBuildKey = "whatsNewSeenBuild"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self,
                                                  userDriverDelegate: self)
        currentRelease = history.release(build: Self.build)
    }

    /// This copy's feed: OrbTorrent's, or a test feed in OrbTorrent Dev.
    private var feedURL: String? {
        if let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String, !feed.isEmpty {
            return feed
        }
        return AppIdentity.isDevelopment ? defaults.string(forKey: Self.testFeedKey) : nil
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    func start() {
        guard !isEnabled, feedURL != nil else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let sparkle = Bundle(for: SPUUpdater.self).object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2"
        // The version and build, and nothing else, so the feed can count
        // the Macs on each version.
        updater.userAgentString = "\(AppIdentity.name)/\(version) (\(Self.build)) Sparkle/\(sparkle)"
        updater.sendsSystemProfile = false
        do {
            try updater.start()
        } catch {
            NSLog("OrbTorrent couldn't start checking for updates: \(error.localizedDescription)")
            return
        }
        isEnabled = true
        checksAutomatically = updater.automaticallyChecksForUpdates
        downloadsAutomatically = updater.automaticallyDownloadsUpdates
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.canCheck = updater.canCheckForUpdates }
            },
            updater.observe(\.lastUpdateCheckDate, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.lastCheck = updater.lastUpdateCheckDate }
            },
        ]
    }

    func checkForUpdates() {
        guard isEnabled else { return }
        NSApp.activate()
        updater.checkForUpdates()
    }

    private func setWaiting(_ name: String?) {
        guard waiting != name else { return }
        waiting = name
        onWaitingChange?(name)
    }

    // MARK: What's New

    /// After an update, gets What's New ready for the window to show. The
    /// first launch of a new install has nothing to show.
    func prepareWhatsNew() {
        let current = Self.build
        guard let seen = defaults.string(forKey: Self.seenBuildKey) else {
            defaults.set(current, forKey: Self.seenBuildKey)
            return
        }
        guard Release.isNewer(current, than: seen) else { return }
        whatsNew = history.releases(after: seen, upTo: current)
        if whatsNew.isEmpty {
            defaults.set(current, forKey: Self.seenBuildKey)
        } else {
            isWhatsNewPresented = true
        }
    }

    func showWhatsNew() {
        guard let currentRelease else { return }
        whatsNew = [currentRelease]
        isWhatsNewPresented = true
    }

    /// What's New on demand in OrbTorrent Dev: the notes it has, or sample
    /// ones before it has read a feed.
    func previewWhatsNew() {
        whatsNew = currentRelease.map { [$0] } ?? Release.samples
        isWhatsNewPresented = true
    }

    func didDismissWhatsNew() {
        defaults.set(Self.build, forKey: Self.seenBuildKey)
    }
}

extension Updates: SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        AppIdentity.isDevelopment ? defaults.string(forKey: Self.testFeedKey) : nil
    }

    /// Keeps every release's notes, including the ones between this version
    /// and the newest, for What's New after updating.
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        history.remember(appcast.items.compactMap(Release.init))
        currentRelease = history.release(build: Self.build)
    }

    func updater(_ updater: SPUUpdater, userDidMake choice: SPUUserUpdateChoice,
                 forUpdate updateItem: SUAppcastItem, state: SPUUserUpdateState) {
        setWaiting(nil)
    }
}

extension Updates: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Sparkle shows a found update right away only when OrbTorrent is in
    /// front and was just opened, rather than over whatever's in use.
    func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem,
                                                              andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus && NSApp.isActive
    }

    func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem,
                                                   state: SPUUserUpdateState) {
        if !handleShowingUpdate {
            setWaiting(Release(update)?.name ?? update.displayVersionString)
        }
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        setWaiting(nil)
    }

    func standardUserDriverWillFinishUpdateSession() {
        setWaiting(nil)
    }

    /// Names versions the way their releases do, such as "1.0 beta 3",
    /// rather than "1.0 (3)".
    func standardUserDriverRequestsVersionDisplayer() -> (any SUVersionDisplay)? {
        self
    }
}

// Sparkle asks on the main thread.
extension Updates: @preconcurrency SUVersionDisplay {
    func formatUpdateVersion(fromUpdate update: SUAppcastItem,
                             andBundleDisplayVersion inOutBundleDisplayVersion: AutoreleasingUnsafeMutablePointer<NSString>,
                             withBundleVersion bundleVersion: String) -> String {
        if let current = history.release(build: bundleVersion)?.title {
            inOutBundleDisplayVersion.pointee = current as NSString
        }
        return Release(update)?.title ?? update.displayVersionString
    }

    func formatBundleDisplayVersion(_ bundleDisplayVersion: String, withBundleVersion bundleVersion: String,
                                    matchingUpdate: SUAppcastItem?) -> String {
        history.release(build: bundleVersion)?.title ?? bundleDisplayVersion
    }
}

extension Release {
    /// A release from an update feed item with notes.
    init?(_ item: SUAppcastItem) {
        guard let notes = item.itemDescription, !notes.isEmpty else { return nil }
        let title = item.title?.trimmingCharacters(in: .whitespaces)
        self.init(build: item.versionString,
                  version: item.displayVersionString,
                  title: title?.isEmpty == false && title != item.displayVersionString ? title : nil,
                  date: item.date,
                  notes: notes,
                  link: item.infoURL)
    }
}
