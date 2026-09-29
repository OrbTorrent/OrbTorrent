import Testing
@testable import OrbTorrent

struct OrbStateTests {
    private func torrent(_ hash: String, _ state: String, progress: Double, size: Int64 = 1_000) -> Torrent {
        Fixtures.torrent(hash: hash, savePath: "/tmp", contentPath: "/tmp/\(hash)",
                         progress: progress, state: state, size: size)
    }

    @Test func followsOnlyTheDownloadsThatAreMoving() {
        let torrents = [torrent("small", "downloading", progress: 0.5), torrent("huge", "stalledDL", progress: 0, size: 1_000_000)]
        #expect(OrbState.overall(of: torrents, moving: ["small"], downloadSpeed: 0) == .downloading(progress: 0.5, energy: 0))
    }

    @Test func aBriefStallStillCountsAsDownloading() {
        let torrents = [torrent("a", "stalledDL", progress: 0.3)]
        #expect(OrbState.overall(of: torrents, moving: ["a"], downloadSpeed: 0) == .downloading(progress: 0.3, energy: 0))
        #expect(OrbState.overall(of: torrents, moving: [], downloadSpeed: 0) == .waiting(progress: 0.3))
    }

    @Test func seedingOutranksWaitingAndPaused() {
        let torrents = [torrent("stuck", "stalledDL", progress: 0), torrent("done", "uploading", progress: 1)]
        #expect(OrbState.overall(of: torrents, moving: [], downloadSpeed: 0) == .seeding)
        let paused = [torrent("p", "stoppedDL", progress: 0.4), torrent("done", "stoppedUP", progress: 1)]
        #expect(OrbState.overall(of: paused, moving: [], downloadSpeed: 0) == .paused(progress: 0.4))
    }

    @Test func restsWhenEverythingIsDoneOrEmpty() {
        #expect(OrbState.overall(of: [], moving: [], downloadSpeed: 0) == .idle)
        #expect(OrbState.overall(of: [torrent("d", "stoppedUP", progress: 1)], moving: [], downloadSpeed: 0) == .finished)
    }

    @Test func energyGrowsWithSpeed() {
        #expect(OrbState.energy(forSpeed: 10_000) == 0)
        #expect(OrbState.energy(forSpeed: 20_000_000) == 1)
        #expect(OrbState.energy(forSpeed: 1_000_000) > 0.4)
    }
}
