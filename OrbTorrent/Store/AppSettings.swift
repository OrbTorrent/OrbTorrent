import Foundation
import Observation

/// OrbTorrent's own preferences (engine preferences live in the engine).
@MainActor
@Observable
final class AppSettings {
    enum AddBehavior: String, CaseIterable, Identifiable {
        case startImmediately
        case askFirst

        var id: String { rawValue }
        var title: String {
            switch self {
            case .startImmediately: "Start downloading right away"
            case .askFirst: "Ask before downloading"
            }
        }
    }

    /// What deleting a download does with its files, everywhere in the app.
    enum DeleteBehavior: String, CaseIterable, Identifiable {
        case moveToTrash
        case deletePermanently

        var id: String { rawValue }
        var title: String {
            switch self {
            case .moveToTrash: "Move its files to the Trash"
            case .deletePermanently: "Delete its files permanently"
            }
        }
    }

    @ObservationIgnored private let defaults: UserDefaults

    var addBehavior: AddBehavior {
        didSet { defaults.set(addBehavior.rawValue, forKey: Keys.addBehavior) }
    }

    var deleteBehavior: DeleteBehavior {
        didSet { defaults.set(deleteBehavior.rawValue, forKey: Keys.deleteBehavior) }
    }

    /// How the window's download list is split into sections.
    var listGrouping: TorrentGrouping {
        didSet { defaults.set(listGrouping.rawValue, forKey: Keys.listGrouping) }
    }

    var openWindowOnAdd: Bool {
        didSet { defaults.set(openWindowOnAdd, forKey: Keys.openWindowOnAdd) }
    }

    var notifyOnCompletion: Bool {
        didSet { defaults.set(notifyOnCompletion, forKey: Keys.notifyOnCompletion) }
    }

    var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Keys.showDockIcon) }
    }

    var preventSleepWhileDownloading: Bool {
        didSet { defaults.set(preventSleepWhileDownloading, forKey: Keys.preventSleepWhileDownloading) }
    }

    /// Pause downloads before their disk fills up, and resume them once there's room.
    var pauseWhenDiskFull: Bool {
        didSet { defaults.set(pauseWhenDiskFull, forKey: Keys.pauseWhenDiskFull) }
    }

    /// Add trackers from a public list to public torrents, so they find more peers.
    var findMorePeers: Bool {
        didSet { defaults.set(findMorePeers, forKey: Keys.findMorePeers) }
    }

    /// Download and share only through a VPN, never the normal connection.
    var vpnOnly: Bool {
        didSet { defaults.set(vpnOnly, forKey: Keys.vpnOnly) }
    }

    /// The VPN to download through, by its service ID; nil for any VPN that
    /// carries internet traffic.
    var vpnServiceID: String? {
        didSet { defaults.set(vpnServiceID, forKey: Keys.vpnServiceID) }
    }

    /// The port a VPN forwards, for VPNs where it's reserved in the account;
    /// nil to ask the VPN for one.
    var vpnForwardedPort: Int? {
        didSet { defaults.set(vpnForwardedPort, forKey: Keys.vpnForwardedPort) }
    }

    /// The user's own program, run when each download finishes: see
    /// FinishedProgram. Only ever set from Settings, by a person.
    var finishedProgram: String? {
        didSet { defaults.set(finishedProgram, forKey: Keys.finishedProgram) }
    }

    /// Add anonymous counts to the daily update check: see AnonymousCounts.
    var sendsAnonymousCounts: Bool {
        didSet { defaults.set(sendsAnonymousCounts, forKey: Keys.sendsAnonymousCounts) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var dismissedDefaultAppBanner: Bool {
        didSet { defaults.set(dismissedDefaultAppBanner, forKey: Keys.dismissedDefaultAppBanner) }
    }

    /// Set once the first-run engine defaults (save folder, upload cap, …) are applied.
    var appliedEngineDefaults: Bool {
        didSet { defaults.set(appliedEngineDefaults, forKey: Keys.appliedEngineDefaults) }
    }

    /// A new install asks before downloading, deletes to the Trash, finds
    /// more peers for public torrents, and sends anonymous counts.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.addBehavior: AddBehavior.askFirst.rawValue,
            Keys.deleteBehavior: DeleteBehavior.moveToTrash.rawValue,
            Keys.openWindowOnAdd: true,
            Keys.notifyOnCompletion: true,
            Keys.showDockIcon: true,
            Keys.preventSleepWhileDownloading: true,
            Keys.pauseWhenDiskFull: true,
            Keys.findMorePeers: true,
            Keys.sendsAnonymousCounts: true,
        ])
        addBehavior = AddBehavior(rawValue: defaults.string(forKey: Keys.addBehavior) ?? "") ?? .askFirst
        deleteBehavior = DeleteBehavior(rawValue: defaults.string(forKey: Keys.deleteBehavior) ?? "") ?? .moveToTrash
        listGrouping = TorrentGrouping(rawValue: defaults.string(forKey: Keys.listGrouping) ?? "") ?? .none
        openWindowOnAdd = defaults.bool(forKey: Keys.openWindowOnAdd)
        notifyOnCompletion = defaults.bool(forKey: Keys.notifyOnCompletion)
        showDockIcon = defaults.bool(forKey: Keys.showDockIcon)
        preventSleepWhileDownloading = defaults.bool(forKey: Keys.preventSleepWhileDownloading)
        pauseWhenDiskFull = defaults.bool(forKey: Keys.pauseWhenDiskFull)
        findMorePeers = defaults.bool(forKey: Keys.findMorePeers)
        vpnOnly = defaults.bool(forKey: Keys.vpnOnly)
        vpnServiceID = defaults.string(forKey: Keys.vpnServiceID)
        vpnForwardedPort = defaults.object(forKey: Keys.vpnForwardedPort) as? Int
        sendsAnonymousCounts = defaults.bool(forKey: Keys.sendsAnonymousCounts)
        finishedProgram = defaults.string(forKey: Keys.finishedProgram)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        dismissedDefaultAppBanner = defaults.bool(forKey: Keys.dismissedDefaultAppBanner)
        appliedEngineDefaults = defaults.bool(forKey: Keys.appliedEngineDefaults)
    }

    private enum Keys {
        static let addBehavior = "addBehavior"
        static let deleteBehavior = "deleteBehavior"
        static let listGrouping = "listGrouping"
        static let openWindowOnAdd = "openWindowOnAdd"
        static let notifyOnCompletion = "notifyOnCompletion"
        static let showDockIcon = "showDockIcon"
        static let preventSleepWhileDownloading = "preventSleepWhileDownloading"
        static let pauseWhenDiskFull = "pauseWhenDiskFull"
        static let findMorePeers = "findMorePeers"
        static let vpnOnly = "vpnOnly"
        static let vpnServiceID = "vpnServiceID"
        static let vpnForwardedPort = "vpnForwardedPort"
        static let sendsAnonymousCounts = "sendsAnonymousCounts"
        static let finishedProgram = "finishedProgram"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let dismissedDefaultAppBanner = "dismissedDefaultAppBanner"
        static let appliedEngineDefaults = "appliedEngineDefaults"
    }
}
