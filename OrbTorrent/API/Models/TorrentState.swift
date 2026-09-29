import Foundation

/// A torrent's state as reported by qBittorrent's Web API.
enum TorrentState: String, Sendable, Decodable {
    case error
    case missingFiles
    case uploading
    case stoppedUP
    case queuedUP
    case stalledUP
    case checkingUP
    case forcedUP
    case allocating
    case downloading
    case metaDL
    case forcedMetaDL
    case stoppedDL
    case queuedDL
    case stalledDL
    case checkingDL
    case forcedDL
    case checkingResumeData
    case moving
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        // qBittorrent 4.x names, kept for older engines.
        case "pausedUP": self = .stoppedUP
        case "pausedDL": self = .stoppedDL
        default: self = TorrentState(rawValue: raw) ?? .unknown
        }
    }

    /// The broad activity group the state belongs to.
    enum Activity: Sendable {
        case downloading, seeding, stopped, completed, checking, queued, stalled, fetchingMetadata, moving, error
    }

    var activity: Activity {
        switch self {
        case .downloading, .forcedDL, .allocating: .downloading
        case .uploading, .forcedUP: .seeding
        case .stoppedDL: .stopped
        case .stoppedUP: .completed
        case .checkingUP, .checkingDL, .checkingResumeData: .checking
        case .queuedUP, .queuedDL: .queued
        case .stalledDL: .stalled
        case .stalledUP: .seeding
        case .metaDL, .forcedMetaDL: .fetchingMetadata
        case .moving: .moving
        case .error, .missingFiles, .unknown: .error
        }
    }

    var isStopped: Bool { self == .stoppedDL || self == .stoppedUP }

    var isForced: Bool { self == .forcedDL || self == .forcedUP || self == .forcedMetaDL }

    /// Whether the engine may be connected to peers for the torrent.
    var mayHavePeers: Bool {
        switch activity {
        case .downloading, .seeding, .stalled, .fetchingMetadata: true
        case .stopped, .completed, .checking, .queued, .moving, .error: false
        }
    }

    var title: String {
        switch self {
        case .error: "Error"
        case .missingFiles: "Files Missing"
        case .uploading, .forcedUP: "Seeding"
        case .stoppedUP: "Completed"
        case .queuedUP: "Queued to Seed"
        case .stalledUP: "Seeding"
        case .checkingUP, .checkingDL: "Checking"
        case .checkingResumeData: "Loading"
        case .allocating: "Allocating"
        case .downloading, .forcedDL: "Downloading"
        case .metaDL, .forcedMetaDL: "Fetching Info"
        case .stoppedDL: "Paused"
        case .queuedDL: "Queued"
        case .stalledDL: "Waiting for Peers"
        case .moving: "Moving"
        case .unknown: "Unknown"
        }
    }
}
