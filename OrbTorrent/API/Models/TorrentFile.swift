import Foundation

/// A file inside a torrent, from `GET /api/v2/torrents/files`.
struct TorrentFile: Identifiable, Hashable, Sendable, Decodable {
    var id: Int { index }

    let index: Int
    /// Path relative to the torrent's save path, including the root folder.
    let name: String
    let size: Int64
    let progress: Double
    let priority: FilePriority
    let availability: Double

    var fileName: String { (name as NSString).lastPathComponent }

    var folder: String? {
        let parent = (name as NSString).deletingLastPathComponent
        return parent.isEmpty ? nil : parent
    }

    var isComplete: Bool { progress >= 1 }
    var isWanted: Bool { priority != .skip }
    var kind: FileKind { FileKind(path: name) }

    private enum CodingKeys: String, CodingKey {
        case index, name, size, progress, priority, availability
    }

    init(index: Int, name: String, size: Int64, progress: Double, priority: FilePriority, availability: Double) {
        self.index = index
        self.name = name
        self.size = size
        self.progress = progress
        self.priority = priority
        self.availability = availability
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        index = try c.decode(Int.self, forKey: .index)
        name = c.value(.name, default: "")
        size = c.value(.size, default: 0)
        progress = c.value(.progress, default: 0)
        priority = c.value(.priority, default: .normal)
        availability = c.value(.availability, default: 0)
    }

    func with(priority: FilePriority) -> TorrentFile {
        TorrentFile(index: index, name: name, size: size, progress: progress, priority: priority, availability: availability)
    }
}
