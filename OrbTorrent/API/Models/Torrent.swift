import Foundation

/// A torrent as returned by `GET /api/v2/torrents/info`.
struct Torrent: Identifiable, Hashable, Sendable, Decodable {
    var id: String { hash }

    let hash: String
    let name: String
    private(set) var state: TorrentState
    /// Fraction of the *selected* files that has been downloaded, 0...1.
    let progress: Double
    /// Size of the selected files, in bytes.
    let size: Int64
    let totalSize: Int64
    let completed: Int64
    let downloaded: Int64
    let uploaded: Int64
    let amountLeft: Int64
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let eta: Int
    let ratio: Double
    let connectedSeeds: Int
    let swarmSeeds: Int
    let connectedPeers: Int
    let swarmPeers: Int
    let availability: Double
    let addedOn: Date?
    let completedOn: Date?
    let savePath: String
    let contentPath: String
    let magnetURI: String
    let sequentialDownload: Bool
    let firstLastPiecePriority: Bool
    let downloadLimit: Int64
    let uploadLimit: Int64
    let tracker: String
    let category: String
    /// Whether its files are known: a magnet link's aren't until peers send them.
    let hasMetadata: Bool
    /// Whether it's from a private tracker; nil until its files are known.
    let isPrivate: Bool?

    var isComplete: Bool { progress >= 1 }

    /// Whether it finished moments ago. One that checks its files again, or
    /// that was brought over from another app, finishes once more with the
    /// date it first finished.
    func finishedJustNow(at now: Date = .now) -> Bool {
        completedOn.map { $0 > now.addingTimeInterval(-10 * 60) } ?? true
    }

    /// Its trackers, which the engine lists in its magnet link.
    var trackerURLs: [String] { MagnetLink(magnetURI)?.trackers ?? [] }

    var kind: FileKind { FileKind(torrentName: name) }

    /// How the download looks just after being paused or resumed, before the
    /// engine reports its new state.
    func assuming(stopped: Bool) -> Torrent {
        var copy = self
        if stopped {
            copy.state = isComplete ? .stoppedUP : .stoppedDL
        } else {
            copy.state = isComplete ? .stalledUP : size > 0 ? .stalledDL : .metaDL
        }
        return copy
    }

    private enum CodingKeys: String, CodingKey {
        case hash, name, state, progress, size, completed, downloaded, uploaded, eta, ratio, availability
        case tracker, category
        case hasMetadata = "has_metadata"
        case isPrivate = "private"
        case totalSize = "total_size"
        case amountLeft = "amount_left"
        case downloadSpeed = "dlspeed"
        case uploadSpeed = "upspeed"
        case connectedSeeds = "num_seeds"
        case swarmSeeds = "num_complete"
        case connectedPeers = "num_leechs"
        case swarmPeers = "num_incomplete"
        case addedOn = "added_on"
        case completedOn = "completion_on"
        case savePath = "save_path"
        case contentPath = "content_path"
        case magnetURI = "magnet_uri"
        case sequentialDownload = "seq_dl"
        case firstLastPiecePriority = "f_l_piece_prio"
        case downloadLimit = "dl_limit"
        case uploadLimit = "up_limit"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hash = try c.decode(String.self, forKey: .hash)
        name = c.value(.name, default: hash)
        state = c.value(.state, default: .unknown)
        progress = c.value(.progress, default: 0)
        size = c.value(.size, default: 0)
        totalSize = c.value(.totalSize, default: 0)
        completed = c.value(.completed, default: 0)
        downloaded = c.value(.downloaded, default: 0)
        uploaded = c.value(.uploaded, default: 0)
        amountLeft = c.value(.amountLeft, default: 0)
        downloadSpeed = c.value(.downloadSpeed, default: 0)
        uploadSpeed = c.value(.uploadSpeed, default: 0)
        eta = c.value(.eta, default: 8_640_000)
        ratio = c.value(.ratio, default: 0)
        connectedSeeds = c.value(.connectedSeeds, default: 0)
        swarmSeeds = c.value(.swarmSeeds, default: 0)
        connectedPeers = c.value(.connectedPeers, default: 0)
        swarmPeers = c.value(.swarmPeers, default: 0)
        availability = c.value(.availability, default: 0)
        addedOn = c.date(.addedOn)
        completedOn = c.date(.completedOn)
        savePath = c.value(.savePath, default: "")
        contentPath = c.value(.contentPath, default: "")
        magnetURI = c.value(.magnetURI, default: "")
        sequentialDownload = c.value(.sequentialDownload, default: false)
        firstLastPiecePriority = c.value(.firstLastPiecePriority, default: false)
        downloadLimit = c.value(.downloadLimit, default: 0)
        uploadLimit = c.value(.uploadLimit, default: 0)
        tracker = c.value(.tracker, default: "")
        category = c.value(.category, default: "")
        // Without these (engines before 5.0) nothing is known to be public.
        hasMetadata = c.value(.hasMetadata, default: true)
        isPrivate = try? c.decodeIfPresent(Bool.self, forKey: .isPrivate)
    }
}
