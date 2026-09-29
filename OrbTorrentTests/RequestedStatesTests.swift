import Foundation
import Testing
@testable import OrbTorrent

@MainActor
struct RequestedStatesTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func torrent(_ state: String, progress: Double = 0.5, size: Int64 = 1_000) -> Torrent {
        Fixtures.torrent(hash: "a", savePath: "/d", contentPath: "/d/x", progress: progress, state: state, size: size)
    }

    @Test func pausedDownloadShowsPausedUntilTheEngineSaysSo() {
        var requested = RequestedStates()
        requested.request(stopped: true, for: ["a"], now: now)
        #expect(requested.apply(to: [torrent("downloading")], now: now).first?.state == .stoppedDL)
        #expect(requested.apply(to: [torrent("downloading", progress: 1)], now: now).first?.state == .stoppedUP)
    }

    @Test func resumedDownloadShowsWhatItWillDoNext() {
        var requested = RequestedStates()
        requested.request(stopped: false, for: ["a"], now: now)
        #expect(requested.apply(to: [torrent("stoppedDL")], now: now).first?.state == .stalledDL)
        #expect(requested.apply(to: [torrent("stoppedUP", progress: 1)], now: now).first?.state == .stalledUP)
        // A magnet link without its file list yet.
        #expect(requested.apply(to: [torrent("stoppedDL", progress: 0, size: 0)], now: now).first?.state == .metaDL)
    }

    @Test func forgetsTheRequestOnceTheEngineCatchesUp() {
        var requested = RequestedStates()
        requested.request(stopped: true, for: ["a"], now: now)
        #expect(requested.apply(to: [torrent("stoppedDL")], now: now).first?.state == .stoppedDL)
        // Resumed from somewhere else afterwards: the engine is right again.
        #expect(requested.apply(to: [torrent("downloading")], now: now).first?.state == .downloading)
    }

    @Test func believesTheEngineAgainAfterAFewSeconds() {
        var requested = RequestedStates()
        requested.request(stopped: true, for: ["a"], now: now)
        let later = now.addingTimeInterval(RequestedStates.grace + 1)
        #expect(requested.apply(to: [torrent("downloading")], now: later).first?.state == .downloading)
    }

    @Test func leavesOtherDownloadsAlone() {
        var requested = RequestedStates()
        requested.request(stopped: true, for: ["other"], now: now)
        #expect(requested.apply(to: [torrent("downloading")], now: now).first?.state == .downloading)
    }
}
