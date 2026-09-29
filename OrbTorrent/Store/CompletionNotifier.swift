import Foundation
import UserNotifications

/// Posts a notification when a download finishes and routes the reply.
@MainActor
final class CompletionNotifier: NSObject, UNUserNotificationCenterDelegate {
    enum Action: String {
        case show = "orbtorrent.show"
        case open = "orbtorrent.open"
        case reveal = "orbtorrent.reveal"
        /// Shows the download's Checks tab.
        case showChecks = "orbtorrent.show-checks"
        case downloadAnyway = "orbtorrent.download-anyway"
        case remove = "orbtorrent.remove"
    }

    /// Called with the torrent hash when someone interacts with a notification.
    var onAction: ((Action, String) -> Void)?

    private var knownCompletion: [String: Bool]?
    private let center = UNUserNotificationCenter.current()
    private static let category = "orbtorrent.download-finished"
    private nonisolated static let heldCategory = "orbtorrent.download-held"
    private nonisolated static let checkCategory = "orbtorrent.check-found"

    override init() {
        super.init()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.category,
                actions: [
                    UNNotificationAction(identifier: Action.open.rawValue, title: "Open"),
                    UNNotificationAction(identifier: Action.reveal.rawValue, title: "Show in Finder"),
                ],
                intentIdentifiers: []
            ),
            UNNotificationCategory(
                identifier: Self.heldCategory,
                actions: [
                    UNNotificationAction(identifier: Action.downloadAnyway.rawValue, title: "Download Anyway"),
                    UNNotificationAction(identifier: Action.remove.rawValue, title: "Remove…", options: [.foreground]),
                ],
                intentIdentifiers: []
            ),
            UNNotificationCategory(identifier: Self.checkCategory, actions: [], intentIdentifiers: []),
        ])
    }

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Compares the new snapshot with the previous one and notifies about
    /// torrents that just finished. The first snapshot only records state.
    func observe(_ torrents: [Torrent], enabled: Bool) {
        let current = Dictionary(torrents.map { ($0.hash, $0.isComplete) }, uniquingKeysWith: { $1 })
        defer { knownCompletion = current }
        guard enabled, let knownCompletion else { return }
        for torrent in torrents where torrent.isComplete && knownCompletion[torrent.hash] == false
            && torrent.finishedJustNow() {
            post(for: torrent)
        }
    }

    private func post(for torrent: Torrent) {
        let content = UNMutableNotificationContent()
        content.title = "Download Finished"
        content.body = torrent.name
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.userInfo = ["hash": torrent.hash]
        center.add(UNNotificationRequest(identifier: "finished-\(torrent.hash)", content: content, trigger: nil))
    }

    /// Says an extension's check is holding a download before it starts.
    func postHeld(_ torrent: Torrent, by records: [CheckRecord]) {
        guard let first = records.first else { return }
        let content = UNMutableNotificationContent()
        content.title = "Download Held"
        content.subtitle = torrent.name
        content.body = "\(first.extensionTitle): \(first.summary)"
        content.sound = .default
        content.categoryIdentifier = Self.heldCategory
        content.userInfo = ["hash": torrent.hash]
        center.add(UNNotificationRequest(identifier: "held-\(torrent.hash)", content: content, trigger: nil))
    }

    /// Says a check after a download finished found something.
    func postFound(_ torrent: Torrent, _ record: CheckRecord) {
        let content = UNMutableNotificationContent()
        content.title = record.extensionTitle
        content.subtitle = torrent.name
        content.body = record.summary
        content.sound = .default
        content.categoryIdentifier = Self.checkCategory
        content.userInfo = ["hash": torrent.hash]
        center.add(UNNotificationRequest(identifier: "check-\(torrent.hash)-\(record.id)", content: content, trigger: nil))
    }

    /// Says downloads were paused because their disk is almost full.
    func postDiskAlmostFull(_ disks: [String], paused count: Int) {
        let content = UNMutableNotificationContent()
        content.title = count == 1 ? "Download Paused" : "Downloads Paused"
        let names = ListFormatter.localizedString(byJoining: disks.map { "“\($0)”" })
        let resumes = count == 1 ? "It resumes by itself" : "They resume by themselves"
        content.body = "\(names) \(disks.count == 1 ? "is" : "are") almost full. \(resumes) once there's \(Format.bytes(DiskSpace.resumeAt)) free."
        content.sound = .default
        center.add(UNNotificationRequest(identifier: "disk-almost-full", content: content, trigger: nil))
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        guard let hash = content.userInfo["hash"] as? String else { return }
        let opensChecks = [Self.heldCategory, Self.checkCategory].contains(content.categoryIdentifier)
        let action = Action(rawValue: response.actionIdentifier) ?? (opensChecks ? .showChecks : .show)
        await MainActor.run { onAction?(action, hash) }
    }
}
