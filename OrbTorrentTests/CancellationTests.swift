import Foundation
import Testing
@testable import OrbTorrent

struct CancellationTests {
    @Test func aRequestCalledOffIsNotAnError() {
        #expect(URLError(.cancelled).isCancellation)
        #expect(CancellationError().isCancellation)
    }

    @Test func realFailuresStillAre() {
        #expect(!URLError(.timedOut).isCancellation)
        #expect(!APIError.unreachable.isCancellation)
    }
}
