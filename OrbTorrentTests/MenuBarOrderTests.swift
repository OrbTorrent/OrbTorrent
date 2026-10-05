import Foundation
import Testing
@testable import OrbTorrent

@MainActor
struct MenuBarOrderTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func torrent(_ hash: String, _ state: String, progress: Double = 0.5, speed: Int64 = 0,
                         addedAgo: TimeInterval = 0, finishedAgo: TimeInterval? = nil) -> Torrent {
        Fixtures.torrent(hash: hash, savePath: "/d", contentPath: "/d/\(hash)", progress: progress, state: state,
                         downloadSpeed: speed, addedOn: now - addedAgo,
                         completedOn: finishedAgo.map { now - $0 })
    }

    @Test func listsEveryDownloadRunningFastestFirstThenPausedThenFinished() {
        let torrents = [
            torrent("finishedEarlier", "stalledUP", progress: 1, finishedAgo: 7_200),
            torrent("slow", "downloading", speed: 100),
            torrent("pausedEarlier", "stoppedDL", addedAgo: 3_600),
            torrent("finishedNow", "uploading", progress: 1, finishedAgo: 60),
            torrent("fast", "downloading", speed: 5_000),
            torrent("pausedNow", "stoppedDL", addedAgo: 60),
        ] + (1...10).map { torrent("older\($0)", "stalledUP", progress: 1, finishedAgo: 86_400 * Double($0)) }

        let order = TorrentStore.menuBarOrder(torrents).map(\.hash)

        #expect(order.count == 16)
        #expect(Array(order.prefix(6)) == ["fast", "slow", "pausedNow", "pausedEarlier", "finishedNow", "finishedEarlier"])
        #expect(order.last == "older10")
    }
}
