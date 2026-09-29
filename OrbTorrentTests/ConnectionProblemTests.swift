import Foundation
import Testing
@testable import OrbTorrent

struct ConnectionProblemTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    @Test func nothingToShowWhenPeersCanReachUs() {
        #expect(ConnectionProblem.current(status: .connected, since: nil, needsPeers: true, now: now) == nil)
    }

    /// The engine is disconnected for a moment after launch, until it's listening.
    @Test func offlineOnlyCountsOnceItLasts() {
        let justNow = now.addingTimeInterval(-2)
        let longAgo = now.addingTimeInterval(-ConnectionProblem.offlineGrace)
        #expect(ConnectionProblem.current(status: .disconnected, since: justNow, needsPeers: false, now: now) == nil)
        #expect(ConnectionProblem.current(status: .disconnected, since: longAgo, needsPeers: false, now: now) == .offline)
    }

    @Test func aBlockOnlyCountsOnceItLastsWhileSomethingNeedsPeers() {
        let justNow = now.addingTimeInterval(-30)
        let longAgo = now.addingTimeInterval(-ConnectionProblem.blockedGrace)
        #expect(ConnectionProblem.current(status: .firewalled, since: justNow, needsPeers: true, now: now) == nil)
        #expect(ConnectionProblem.current(status: .firewalled, since: longAgo, needsPeers: false, now: now) == nil)
        #expect(ConnectionProblem.current(status: .firewalled, since: longAgo, needsPeers: true, now: now) == .incomingBlocked)
    }
}
