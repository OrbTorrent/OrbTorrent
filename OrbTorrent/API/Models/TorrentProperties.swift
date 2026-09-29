import Foundation

/// Extra details from `GET /api/v2/torrents/properties`.
struct TorrentProperties: Sendable, Decodable, Equatable {
    let pieceSize: Int64
    let piecesHave: Int
    let piecesTotal: Int
    let wasted: Int64
    let timeActive: Int
    let seedingTime: Int
    let connections: Int
    let averageDownloadSpeed: Int64
    let createdBy: String
    let comment: String
    let createdOn: Date?
    let isPrivate: Bool

    private enum CodingKeys: String, CodingKey {
        case comment
        case pieceSize = "piece_size"
        case piecesHave = "pieces_have"
        case piecesTotal = "pieces_num"
        case wasted = "total_wasted"
        case timeActive = "time_elapsed"
        case seedingTime = "seeding_time"
        case connections = "nb_connections"
        case averageDownloadSpeed = "dl_speed_avg"
        case createdBy = "created_by"
        case createdOn = "creation_date"
        case isPrivate = "is_private"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pieceSize = c.value(.pieceSize, default: 0)
        piecesHave = c.value(.piecesHave, default: 0)
        piecesTotal = c.value(.piecesTotal, default: 0)
        wasted = c.value(.wasted, default: 0)
        timeActive = c.value(.timeActive, default: 0)
        seedingTime = c.value(.seedingTime, default: 0)
        connections = c.value(.connections, default: 0)
        averageDownloadSpeed = c.value(.averageDownloadSpeed, default: 0)
        createdBy = c.value(.createdBy, default: "")
        comment = c.value(.comment, default: "")
        createdOn = c.date(.createdOn)
        isPrivate = c.value(.isPrivate, default: false)
    }
}
