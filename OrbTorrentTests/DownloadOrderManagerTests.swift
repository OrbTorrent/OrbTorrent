import Foundation
import Testing
@testable import OrbTorrent

@MainActor
final class DownloadOrderManagerTests {
    private let suite = TestDefaults.makeSuiteName()

    deinit {
        TestDefaults.remove(suite)
    }

    private func makeManager() -> DownloadOrderManager {
        DownloadOrderManager(defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func firstUnfinishedFileGetsMaximumThenHigh() {
        let manager = makeManager()
        let files = [Fixtures.file(0, "E01.mkv"), Fixtures.file(1, "E02.mkv"), Fixtures.file(2, "E03.mkv")]
        manager.enable(for: "h", files: files)
        manager.move(in: "h", files: files, from: IndexSet(integer: 2), to: 0) // E03, E01, E02

        let priorities = manager.desiredPriorities(for: files, hash: "h")
        #expect(priorities[2] == .maximum)
        #expect(priorities[0] == .high)
        #expect(priorities[1] == .normal)
    }

    @Test func movesOnWhenAFileCompletes() {
        let manager = makeManager()
        let files = [Fixtures.file(0, "a", progress: 1), Fixtures.file(1, "b"), Fixtures.file(2, "c")]
        manager.enable(for: "h", files: files)

        let priorities = manager.desiredPriorities(for: files, hash: "h")
        #expect(priorities[0] == .normal)
        #expect(priorities[1] == .maximum)
        #expect(priorities[2] == .high)
    }

    @Test func skippedFilesStaySkippedAndUnranked() {
        let manager = makeManager()
        let files = [Fixtures.file(0, "a", priority: 0), Fixtures.file(1, "b")]
        manager.enable(for: "h", files: files)

        let priorities = manager.desiredPriorities(for: files, hash: "h")
        #expect(priorities[0] == nil)
        #expect(priorities[1] == .maximum)
        #expect(manager.position(of: files[0], in: files, hash: "h") == nil)
        #expect(manager.position(of: files[1], in: files, hash: "h") == 1)
    }

    @Test func downloadNextMovesAFileToTheFront() {
        let manager = makeManager()
        let files = [Fixtures.file(0, "a"), Fixtures.file(1, "b"), Fixtures.file(2, "c")]
        manager.enable(for: "h", files: files)
        manager.moveToFront(2, in: "h", files: files)
        #expect(manager.ordered(files, for: "h").map(\.index) == [2, 0, 1])
    }
}
