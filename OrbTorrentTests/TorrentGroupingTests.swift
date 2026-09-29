import Foundation
import Testing
@testable import OrbTorrent

@MainActor
struct TorrentGroupingTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kuala_Lumpur")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    /// 24 Sep 2026, 10:00 MYT.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 10))! }

    private func added(_ days: Int, hours: Int = 0, hash: String) -> Torrent {
        let date = now.addingTimeInterval(-Double(days) * 86_400 - Double(hours) * 3_600)
        return Fixtures.torrent(hash: hash, savePath: "/d", contentPath: "/d/x", addedOn: date)
    }

    @Test func noGroupingLeavesTheListAlone() {
        #expect(TorrentGrouping.none.groups(of: [added(0, hash: "a")]) == nil)
    }

    @Test func groupsByDateAddedNewestFirst() {
        let torrents = [
            added(400, hash: "lastYear"),
            added(0, hash: "today"),
            added(1, hash: "yesterday"),
            added(0, hours: 11, hash: "lateYesterday"),
            added(5, hash: "thisWeek"),
            added(20, hash: "thisMonth"),
            added(100, hash: "june"),
        ]
        let groups = TorrentGrouping.dateAdded.groups(of: torrents, now: now, calendar: calendar)!

        #expect(groups.map(\.title) == ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "June", "2025"])
        #expect(groups[1].torrents.map(\.hash) == ["yesterday", "lateYesterday"])
    }

    @Test func groupsByStatusWithWorkInProgressFirst() {
        let torrents = [
            Fixtures.torrent(hash: "done", savePath: "/d", contentPath: "/d/x", progress: 1, state: "stoppedUP"),
            Fixtures.torrent(hash: "busy", savePath: "/d", contentPath: "/d/x", state: "downloading"),
            Fixtures.torrent(hash: "held", savePath: "/d", contentPath: "/d/x", state: "stoppedDL"),
            Fixtures.torrent(hash: "idle", savePath: "/d", contentPath: "/d/x", state: "stalledDL"),
        ]
        let groups = TorrentGrouping.status.groups(of: torrents)!

        #expect(groups.map(\.title) == ["Downloading", "Waiting", "Paused", "Completed"])
    }
}
