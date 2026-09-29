import Foundation

/// Sort orders for the torrent list.
enum TorrentSort: String, CaseIterable, Identifiable {
    case dateAdded, name, progress, size, downloadSpeed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dateAdded: "Date Added"
        case .name: "Name"
        case .progress: "Progress"
        case .size: "Size"
        case .downloadSpeed: "Download Speed"
        }
    }

    func areInIncreasingOrder(_ lhs: Torrent, _ rhs: Torrent) -> Bool {
        switch self {
        case .dateAdded:
            (lhs.addedOn ?? .distantPast) > (rhs.addedOn ?? .distantPast)
        case .name:
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .progress:
            lhs.progress > rhs.progress
        case .size:
            lhs.size > rhs.size
        case .downloadSpeed:
            lhs.downloadSpeed > rhs.downloadSpeed
        }
    }
}
