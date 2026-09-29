import Foundation
import Observation

/// Lets people download a torrent's files one after another in a chosen order.
///
/// qBittorrent only has four priority levels, so OrbTorrent keeps the order itself
/// and continuously assigns them: the first unfinished file gets Maximum, the
/// next High, and the rest Normal. As each file finishes, the next one moves up.
@MainActor
@Observable
final class DownloadOrderManager {
    private(set) var orders: [String: [Int]]

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "downloadOrders"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        orders = (defaults.dictionary(forKey: Self.key) as? [String: [Int]]) ?? [:]
    }

    func isOrdered(_ hash: String) -> Bool {
        orders[hash] != nil
    }

    /// Files in their download order; files not yet in the order go last.
    func ordered(_ files: [TorrentFile], for hash: String) -> [TorrentFile] {
        guard let order = orders[hash] else { return files }
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return files.sorted { (rank[$0.index] ?? Int.max, $0.index) < (rank[$1.index] ?? Int.max, $1.index) }
    }

    /// Starts ordering with the files' current priorities as the initial order.
    func enable(for hash: String, files: [TorrentFile]) {
        let initial = files.sorted { lhs, rhs in
            if lhs.priority.rawValue != rhs.priority.rawValue { return lhs.priority.rawValue > rhs.priority.rawValue }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        orders[hash] = initial.map(\.index)
        save()
    }

    func disable(for hash: String) {
        orders[hash] = nil
        save()
    }

    func move(in hash: String, files: [TorrentFile], from source: IndexSet, to destination: Int) {
        var current = ordered(files, for: hash).map(\.index)
        current.move(fromOffsets: source, toOffset: destination)
        orders[hash] = current
        save()
    }

    func moveToFront(_ index: Int, in hash: String, files: [TorrentFile]) {
        var current = ordered(files, for: hash).map(\.index)
        current.removeAll { $0 == index }
        current.insert(index, at: 0)
        orders[hash] = current
        save()
    }

    func forget(_ hashes: some Sequence<String>) {
        var changed = false
        for hash in hashes where orders[hash] != nil {
            orders[hash] = nil
            changed = true
        }
        if changed { save() }
    }

    /// The priority each wanted file should have right now.
    func desiredPriorities(for files: [TorrentFile], hash: String) -> [Int: FilePriority] {
        var result: [Int: FilePriority] = [:]
        var rank = 0
        for file in ordered(files, for: hash) where file.isWanted {
            if file.isComplete {
                result[file.index] = .normal
                continue
            }
            result[file.index] = switch rank {
            case 0: .maximum
            case 1: .high
            default: .normal
            }
            rank += 1
        }
        return result
    }

    /// 1-based position among the wanted files, for display.
    func position(of file: TorrentFile, in files: [TorrentFile], hash: String) -> Int? {
        guard file.isWanted else { return nil }
        let wanted = ordered(files, for: hash).filter(\.isWanted)
        return wanted.firstIndex(where: { $0.index == file.index }).map { $0 + 1 }
    }

    private func save() {
        defaults.set(orders, forKey: Self.key)
    }
}
