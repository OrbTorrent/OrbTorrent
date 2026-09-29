import Foundation

/// A magnet link's metadata from `POST /api/v2/torrents/fetchMetadata`, once
/// the link's peers have sent it.
struct FetchedMetadata: Decodable {
    let metadata: TorrentMetadata

    private enum CodingKeys: String, CodingKey {
        case hash, info, comment
    }

    private struct Info: Decodable {
        let name: String
        /// Numbered as the engine numbers them, without padding files.
        let files: [File]
        let `private`: Bool?
    }

    private struct File: Decodable {
        let path: String
        let length: Int64
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let info = try c.decode(Info.self, forKey: .info)
        let comment = c.value(.comment, default: "")
        metadata = TorrentMetadata(
            infoHash: try c.decode(String.self, forKey: .hash),
            name: info.name,
            files: info.files.enumerated().map { TorrentMetadata.File(id: $0.offset, path: $0.element.path, size: $0.element.length) },
            comment: comment.isEmpty ? nil : comment,
            isPrivate: info.private ?? false
        )
    }
}
