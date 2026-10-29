import CryptoKit
import Foundation
import Testing
@testable import OrbTorrent

struct TorrentMetadataTests {
    private func bencodeString(_ value: String) -> String { "\(value.utf8.count):\(value)" }

    @Test func computesV1InfoHashFromExactInfoBytes() throws {
        let info = "d6:lengthi1024e4:name8:file.bin12:piece lengthi16384e6:pieces20:\(String(repeating: "x", count: 20))e"
        let torrent = "d8:announce\(bencodeString("udp://tracker.example:1337"))4:info\(info)e"
        let metadata = try TorrentMetadata(data: Data(torrent.utf8))

        let expected = Insecure.SHA1.hash(data: Data(info.utf8)).map { String(format: "%02x", $0) }.joined()
        #expect(metadata.infoHash == expected)
        #expect(metadata.name == "file.bin")
        #expect(metadata.files.map(\.path) == ["file.bin"])
        #expect(metadata.totalSize == 1024)
    }

    @Test func listsMultiFileTorrentsUnderTheirFolder() throws {
        let files = "l"
            + "d6:lengthi100e4:pathl\(bencodeString("a.mkv"))ee"
            + "d6:lengthi200e4:pathl\(bencodeString("Subs"))\(bencodeString("a.srt"))ee"
            + "e"
        let info = "d5:files\(files)4:name\(bencodeString("Show"))12:piece lengthi16384e6:pieces20:\(String(repeating: "y", count: 20))e"
        let metadata = try TorrentMetadata(data: Data("d4:info\(info)e".utf8))

        #expect(metadata.files.map(\.path) == ["Show/a.mkv", "Show/Subs/a.srt"])
        #expect(metadata.files.map(\.id) == [0, 1])
        #expect(metadata.totalSize == 300)
    }

    @Test func leavesOutPaddingFilesAsTheEngineDoes() throws {
        // A BEP 47 padding file and BitComet's older kind, between two real files.
        let files = "l"
            + "d6:lengthi100e4:pathl\(bencodeString("a.mkv"))ee"
            + "d4:attr1:p6:lengthi16284e4:pathl\(bencodeString(".pad"))\(bencodeString("16284"))ee"
            + "d6:lengthi50e4:pathl\(bencodeString("_____padding_file_0_"))ee"
            + "d6:lengthi200e4:pathl\(bencodeString("b.mkv"))ee"
            + "e"
        let info = "d5:files\(files)4:name\(bencodeString("Show"))12:piece lengthi16384e6:pieces20:\(String(repeating: "z", count: 20))e"
        let metadata = try TorrentMetadata(data: Data("d4:info\(info)e".utf8))

        #expect(metadata.files.map(\.path) == ["Show/a.mkv", "Show/b.mkv"])
        #expect(metadata.files.map(\.id) == [0, 1])
        #expect(metadata.totalSize == 300)
    }

    @Test func rejectsFilesThatAreNotTorrents() {
        #expect(throws: TorrentMetadata.ParseError.self) {
            try TorrentMetadata(data: Data("<html>not a torrent</html>".utf8))
        }
    }

    /// A file can't run the decoder out of stack by nesting lists.
    @Test func refusesValuesNestedTooDeep() throws {
        let nested = String(repeating: "l", count: 100_000) + String(repeating: "e", count: 100_000)
        var decoder = BencodeDecoder(data: Data(nested.utf8))
        #expect(throws: BencodeError.self) { try decoder.decode() }
        #expect(throws: TorrentMetadata.ParseError.self) {
            try TorrentMetadata(data: Data("d4:info\(nested)e".utf8))
        }

        // As deep as allowed still reads.
        let deepest = String(repeating: "l", count: BencodeDecoder.maximumDepth) + String(repeating: "e", count: BencodeDecoder.maximumDepth)
        var allowed = BencodeDecoder(data: Data(deepest.utf8))
        _ = try allowed.decode()
        let tooDeep = "l" + deepest + "e"
        var refused = BencodeDecoder(data: Data(tooDeep.utf8))
        #expect(throws: BencodeError.self) { try refused.decode() }
    }

    @Test func refusesTorrentsWithTooManyFilesOrFolders() throws {
        let pieces = "12:piece lengthi16384e6:pieces20:\(String(repeating: "p", count: 20))"
        func torrent(files count: Int, depth: Int = 1) -> Data {
            let path = "l" + String(repeating: bencodeString("a"), count: depth) + "e"
            let files = "l" + String(repeating: "d6:lengthi1e4:path\(path)e", count: count) + "e"
            return Data("d4:infod5:files\(files)4:name\(bencodeString("Debian"))\(pieces)ee".utf8)
        }
        let limits = TorrentMetadata.Limits(files: 3, pathComponents: 4)
        #expect(try TorrentMetadata(data: torrent(files: 3, depth: 4), limits: limits).files.count == 3)
        #expect(throws: TorrentMetadata.ParseError.tooLarge) { try TorrentMetadata(data: torrent(files: 4), limits: limits) }
        #expect(throws: TorrentMetadata.ParseError.tooLarge) { try TorrentMetadata(data: torrent(files: 1, depth: 5), limits: limits) }

        // The real limits: a file 4 097 folders deep.
        #expect(throws: TorrentMetadata.ParseError.tooLarge) { try TorrentMetadata(data: torrent(files: 1, depth: 4_097)) }
        #expect(try TorrentMetadata(data: torrent(files: 1, depth: 4_096)).files.count == 1)
        #expect(TorrentMetadata.Limits().files == 1_000_000)
    }

    /// A string whose length is near Int.max is refused, rather than
    /// overflowing while the decoder finds where it ends.
    @Test func refusesAStringLongerThanTheFile() {
        for length in ["9223372036854775807", "9223372036854775800", "99999999999999999999"] {
            var decoder = BencodeDecoder(data: Data("d\(length):4:infodee".utf8))
            #expect(throws: BencodeError.self) { try decoder.decode() }
            #expect(throws: TorrentMetadata.ParseError.notATorrent) {
                try TorrentMetadata(data: Data("d\(length):4:infodee".utf8))
            }
        }
    }

    /// Sizes below zero, or adding up to more than any torrent could hold,
    /// are refused, so totals of them can't overflow.
    @Test func refusesSizesThatDontAddUp() throws {
        let pieces = "12:piece lengthi16384e6:pieces20:\(String(repeating: "q", count: 20))"
        func torrent(lengths: [Int64]) -> Data {
            let files = "l" + lengths.map { "d6:lengthi\($0)e4:pathl\(bencodeString("f\($0)"))ee" }.joined() + "e"
            return Data("d4:infod5:files\(files)4:name\(bencodeString("Sintel"))\(pieces)ee".utf8)
        }
        for lengths: [Int64] in [[5_000_000_000_000_000_000, 5_000_000_000_000_000_000], [-1, 10], [Int64.max], [1 << 52, 1 << 52, 1]] {
            #expect(throws: TorrentMetadata.ParseError.notATorrent, "\(lengths)") { try TorrentMetadata(data: torrent(lengths: lengths)) }
        }
        let largest = try TorrentMetadata(data: torrent(lengths: [1 << 52, 1 << 52]))
        #expect(largest.totalSize == TorrentMetadata.maximumTotalSize)

        // A single file, and a version 2 file tree.
        #expect(throws: TorrentMetadata.ParseError.notATorrent) {
            try TorrentMetadata(data: Data("d4:infod6:lengthi-5e4:name\(bencodeString("Sintel.mkv"))\(pieces)ee".utf8))
        }
        let leaf = "d0:d6:lengthi9000000000000000000eee"
        let tree = "d\(bencodeString("a"))\(leaf)\(bencodeString("b"))\(leaf)e"
        #expect(throws: TorrentMetadata.ParseError.notATorrent) {
            try TorrentMetadata(data: Data("d4:infod9:file tree\(tree)12:meta versioni2e4:name\(bencodeString("Sintel"))ee".utf8))
        }
    }

    @Test func refusesVersion2FileTreesWithTooManyFiles() {
        let leaf = "d0:d6:lengthi1eee"
        let tree = "d" + (0..<4).map { "\(bencodeString("f\($0)"))\(leaf)" }.joined() + "e"
        let data = Data("d4:infod9:file tree\(tree)12:meta versioni2e4:name\(bencodeString("Fedora"))ee".utf8)
        #expect(throws: TorrentMetadata.ParseError.tooLarge) {
            try TorrentMetadata(data: data, limits: TorrentMetadata.Limits(files: 3))
        }
        #expect((try? TorrentMetadata(data: data, limits: TorrentMetadata.Limits(files: 4)))?.files.count == 4)
    }
}
