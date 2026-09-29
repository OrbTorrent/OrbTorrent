import Foundation
import Testing
@testable import OrbTorrent

/// "Remove and Move Files to Trash" must only ever touch the download itself.
@MainActor
struct FileActionsTests {
    private let home = URL(fileURLWithPath: "/Users/tester")

    @Test func trashesTheTorrentsOwnFolderInsideDownloads() {
        let torrent = Fixtures.torrent(savePath: "/Users/tester/Downloads",
                                       contentPath: "/Users/tester/Downloads/Show")
        let targets = FileActions.trashTargets(for: torrent, files: [], home: home)
        #expect(targets.map(\.path) == ["/Users/tester/Downloads/Show"])
    }

    @Test func trashesASingleFileDownload() {
        let torrent = Fixtures.torrent(savePath: "/Users/tester/Downloads",
                                       contentPath: "/Users/tester/Downloads/movie.mkv")
        let targets = FileActions.trashTargets(for: torrent, files: [], home: home)
        #expect(targets.map(\.path) == ["/Users/tester/Downloads/movie.mkv"])
    }

    @Test func neverTrashesTheSaveFolderItself() {
        // A torrent saved without its own folder reports the save folder as its content path.
        let torrent = Fixtures.torrent(savePath: "/Users/tester/Downloads",
                                       contentPath: "/Users/tester/Downloads")
        let files = [Fixtures.file(0, "a.mkv"), Fixtures.file(1, "b.srt")]
        let targets = FileActions.trashTargets(for: torrent, files: files, home: home)
        #expect(targets.map(\.path) == ["/Users/tester/Downloads/a.mkv", "/Users/tester/Downloads/b.srt"])
    }

    @Test func ignoresPathsThatEscapeTheSaveFolder() {
        let torrent = Fixtures.torrent(savePath: "/Users/tester/Downloads",
                                       contentPath: "/Users/tester/Documents")
        let files = [Fixtures.file(0, "../Documents/secret.txt")]
        let targets = FileActions.trashTargets(for: torrent, files: files, home: home)
        #expect(targets.isEmpty)
    }

    @Test func findsTheEnginesPartsFileInTheSaveFolder() {
        let torrent = Fixtures.torrent(hash: "86b54f32", savePath: "/Users/tester/Downloads",
                                       contentPath: "/Users/tester/Downloads/Show")
        #expect(FileActions.partsFile(of: torrent)?.path == "/Users/tester/Downloads/.86b54f32.parts")
    }

    @Test func neverTrashesHomeOrStandardFolders() {
        let torrent = Fixtures.torrent(savePath: "/Users/tester",
                                       contentPath: "/Users/tester/Downloads")
        let targets = FileActions.trashTargets(for: torrent, files: [], home: home)
        #expect(targets.isEmpty)
    }
}
