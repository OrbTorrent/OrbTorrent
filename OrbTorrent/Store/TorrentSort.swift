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

    /// `name` gives the name a download is shown by.
    func areInIncreasingOrder(_ lhs: Torrent, _ rhs: Torrent, name: (String) -> String = { $0 }) -> Bool {
        switch self {
        case .dateAdded:
            (lhs.addedOn ?? .distantPast) > (rhs.addedOn ?? .distantPast)
        case .name:
            name(lhs.name).localizedStandardCompare(name(rhs.name)) == .orderedAscending
        case .progress:
            lhs.progress > rhs.progress
        case .size:
            lhs.size > rhs.size
        case .downloadSpeed:
            lhs.downloadSpeed > rhs.downloadSpeed
        }
    }
}
