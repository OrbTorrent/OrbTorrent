import Foundation

/// A file's download priority. qBittorrent exposes libtorrent's 0...7 scale but
/// only uses four steps; other values are folded into the nearest one.
enum FilePriority: Int, CaseIterable, Identifiable, Sendable, Decodable {
    case skip = 0
    case normal = 1
    case high = 6
    case maximum = 7

    var id: Int { rawValue }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(Int.self)
        self = FilePriority(rawValue: raw) ?? (raw <= 0 ? .skip : raw >= 7 ? .maximum : raw >= 6 ? .high : .normal)
    }

    var title: String {
        switch self {
        case .skip: "Don't Download"
        case .normal: "Normal"
        case .high: "High"
        case .maximum: "Maximum"
        }
    }

    /// Circle symbols, matching the tick shown for finished files.
    var symbol: String {
        switch self {
        case .skip: "xmark.circle"
        case .normal: "arrow.down.circle"
        case .high: "chevron.up.circle"
        case .maximum: "chevron.up.circle.fill"
        }
    }
}
