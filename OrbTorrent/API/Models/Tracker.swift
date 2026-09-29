import Foundation

/// A tracker entry from `GET /api/v2/torrents/trackers`.
struct Tracker: Identifiable, Hashable, Sendable, Decodable {
    var id: String { url }

    enum Status: Int, Sendable, Decodable {
        case disabled = 0
        case notContacted = 1
        case working = 2
        case updating = 3
        case notWorking = 4
        case trackerError = 5
        case unreachable = 6

        var title: String {
            switch self {
            case .disabled: "Disabled"
            case .notContacted: "Not Contacted Yet"
            case .working: "Working"
            case .updating: "Updating"
            case .notWorking: "Not Working"
            case .trackerError: "Tracker Error"
            case .unreachable: "Unreachable"
            }
        }
    }

    let url: String
    let status: Status
    let tier: Int
    let peers: Int
    let seeds: Int
    let leechers: Int
    let message: String

    /// DHT, PeX and LSD appear as pseudo-trackers named like "** [DHT] **".
    var isPeerSource: Bool { url.hasPrefix("** [") }

    var displayName: String {
        if isPeerSource {
            return url.replacingOccurrences(of: "** [", with: "").replacingOccurrences(of: "] **", with: "")
        }
        return URL(string: url)?.host() ?? url
    }

    private enum CodingKeys: String, CodingKey {
        case url, status, tier, msg
        case peers = "num_peers"
        case seeds = "num_seeds"
        case leechers = "num_leeches"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        url = c.value(.url, default: "")
        status = c.value(.status, default: .notContacted)
        // Tier is a number for real trackers and an empty string for DHT/PeX/LSD.
        tier = c.value(.tier, default: -1)
        peers = max(c.value(.peers, default: 0), 0)
        seeds = max(c.value(.seeds, default: 0), 0)
        leechers = max(c.value(.leechers, default: 0), 0)
        message = c.value(.msg, default: "")
    }
}
