import Foundation
import Testing
@testable import OrbTorrent

@MainActor
struct MagnetFilesTests {
    private let hash = "e4f19cf636409b72571766c2ae89c98fc21a109d"

    @Test func readsTheFilesPeersSentForAMagnetLink() throws {
        // Shaped like qBittorrent 5.2.3's POST /api/v2/torrents/fetchMetadata, once it has them.
        let json = """
        {"comment":"","created_by":"mktorrent","creation_date":1790100000,"hash":"\(hash)","infohash_v1":"\(hash)",
         "infohash_v2":"","info":{"files":[{"length":100,"path":"Show/a.mkv"},{"length":200,"path":"Show/Subs/a.srt"}],
         "length":300,"name":"Show","piece_length":16384,"pieces_num":1,"private":false},
         "trackers":[{"tier":0,"url":"https://torrent.ubuntu.com/announce"}],"webseeds":[]}
        """
        let metadata = try JSONDecoder().decode(FetchedMetadata.self, from: Data(json.utf8)).metadata
        #expect(metadata.infoHash == hash)
        #expect(metadata.name == "Show")
        #expect(metadata.files.map(\.path) == ["Show/a.mkv", "Show/Subs/a.srt"])
        #expect(metadata.files.map(\.id) == [0, 1])
        #expect(metadata.totalSize == 300)
        #expect(metadata.comment == nil)
    }

    @Test func aMagnetLinkShowsItsFilesOncePeersSendThem() throws {
        let link = try #require(MagnetLink("magnet:?xt=urn:btih:\(hash)&dn=Name+in+the+Link"))
        var pending = AddTorrentCoordinator.Pending(source: .magnet(link))
        #expect(pending.name == "Name in the Link")
        #expect(pending.metadata == nil)
        #expect(pending.neededBytes == nil)

        pending.fetchedMetadata = TorrentMetadata(infoHash: hash, name: "Real Name", files: [
            .init(id: 0, path: "Real Name/a.mkv", size: 100),
            .init(id: 1, path: "Real Name/b.mkv", size: 200),
        ])
        pending.skippedFiles = [1]
        #expect(pending.name == "Real Name")
        #expect(pending.metadata?.files.count == 2)
        #expect(pending.neededBytes == 100)
    }
}
