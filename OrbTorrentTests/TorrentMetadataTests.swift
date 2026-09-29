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
}
