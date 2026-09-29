import Foundation
import Testing
@testable import OrbTorrent

@MainActor
struct DiskSpaceTests {
    private let gb: Int64 = 1_000_000_000
    private let disconnected = "/Volumes/OrbTorrent Test Disk That Isn't Connected/Downloads"

    @Test func fitsOnlyWithTheReserveLeftOver() {
        let room = DiskSpace.Room(disk: "Disk", available: 20 * gb, othersNeed: 5 * gb)
        #expect(room.fits(10 * gb))
        #expect(!room.fits(10 * gb + 1))
    }

    @Test func findsTheDiskOfAFolderNotCreatedYet() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-\(UUID().uuidString)/Show/Season 1")
        let disk = try #require(DiskSpace.volume(containing: folder.path))
        #expect(disk.available > 0)
        #expect(!disk.name.isEmpty)
    }

    @Test func aDiskThatIsNotConnectedHasNoSpace() {
        #expect(DiskSpace.volume(containing: disconnected) == nil)
    }

    @Test func countsOnlyDownloadsOnTheSameDisk() throws {
        let folder = FileManager.default.temporaryDirectory.path
        let room = try #require(DiskSpace.room(forFolder: folder, downloads: [
            DiskSpace.Download(savePath: folder, remaining: 3 * gb),
            DiskSpace.Download(savePath: disconnected, remaining: 5 * gb),
        ]))
        #expect(room.othersNeed == 3 * gb)
    }
}

@MainActor
struct DiskSpaceGuardTests {
    private let gb: Int64 = 1_000_000_000

    private func torrent(_ hash: String, _ state: String, progress: Double = 0.5, in folder: String = "/disk") -> Torrent {
        Fixtures.torrent(hash: hash, savePath: folder, contentPath: "\(folder)/\(hash)", progress: progress, state: state)
    }

    private func disk(_ available: Int64) -> [String: DiskSpace.Volume] {
        ["/disk": DiskSpace.Volume(id: URL(fileURLWithPath: "/disk"), name: "Disk", available: available)]
    }

    private func withGuard(_ body: (DiskSpaceGuard, UserDefaults) -> Void) {
        let suite = TestDefaults.makeSuiteName()
        defer { TestDefaults.remove(suite) }
        let defaults = UserDefaults(suiteName: suite)!
        body(DiskSpaceGuard(defaults: defaults), defaults)
    }

    @Test func pausesRunningDownloadsWhenTheDiskIsAlmostFull() {
        withGuard { diskGuard, _ in
            let torrents = [
                torrent("running", "downloading"),
                torrent("pausedByYou", "stoppedDL"),
                torrent("finished", "stalledUP", progress: 1),
            ]
            let decision = diskGuard.evaluate(torrents, enabled: true, volumes: disk(4 * gb))
            #expect(decision.pause == ["running"])
            #expect(decision.fullDisks == ["Disk"])
            #expect(diskGuard.waiting == ["running"])
        }
    }

    @Test func resumesOnceThereIsRoomToSpare() {
        withGuard { diskGuard, _ in
            _ = diskGuard.evaluate([torrent("a", "downloading")], enabled: true, volumes: disk(4 * gb))
            let paused = [torrent("a", "stoppedDL"), torrent("mine", "stoppedDL")]

            // Just over the reserve isn't enough, so it doesn't stop and start.
            let between = diskGuard.evaluate(paused, enabled: true, volumes: disk(6 * gb))
            #expect(between.resume.isEmpty && between.pause.isEmpty)
            #expect(between.fullDisks == ["Disk"])

            let roomy = diskGuard.evaluate(paused, enabled: true, volumes: disk(7 * gb))
            #expect(roomy.resume == ["a"])
            #expect(roomy.fullDisks.isEmpty)
            #expect(diskGuard.waiting.isEmpty)
        }
    }

    @Test func turningTheSettingOffResumesWhatItPaused() {
        withGuard { diskGuard, _ in
            _ = diskGuard.evaluate([torrent("a", "downloading")], enabled: true, volumes: disk(4 * gb))
            let decision = diskGuard.evaluate([torrent("a", "stoppedDL")], enabled: false, volumes: disk(4 * gb))
            #expect(decision.resume == ["a"])
            #expect(decision.pause.isEmpty)
        }
    }

    @Test func forgetsRemovedAndFinishedDownloads() {
        withGuard { diskGuard, _ in
            _ = diskGuard.evaluate([torrent("gone", "downloading"), torrent("done", "downloading")],
                                   enabled: true, volumes: disk(4 * gb))
            let decision = diskGuard.evaluate([torrent("done", "stoppedUP", progress: 1)], enabled: true, volumes: disk(4 * gb))
            #expect(decision.fullDisks.isEmpty)
            #expect(diskGuard.waiting.isEmpty)
        }
    }

    @Test func remembersPausedDownloadsAcrossLaunches() {
        withGuard { diskGuard, defaults in
            _ = diskGuard.evaluate([torrent("a", "downloading")], enabled: true, volumes: disk(4 * gb))
            #expect(DiskSpaceGuard(defaults: defaults).waiting == ["a"])
        }
    }

    @Test func leavesDownloadsOnDisconnectedDisksAlone() {
        withGuard { diskGuard, _ in
            let decision = diskGuard.evaluate([torrent("a", "downloading", in: "/elsewhere")], enabled: true, volumes: disk(4 * gb))
            #expect(decision == DiskSpaceGuard.Decision())
        }
    }
}
