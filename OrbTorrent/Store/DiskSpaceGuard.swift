import Foundation

/// Pauses downloads before their disk fills up, and resumes them once there's
/// room again. The downloads it paused are remembered across launches.
@MainActor
final class DiskSpaceGuard {
    struct Decision: Equatable {
        /// Downloads to pause now.
        var pause: [String] = []
        /// Downloads that were waiting for space and can resume.
        var resume: [String] = []
        /// The disks downloads are waiting on, by name.
        var fullDisks: [String] = []
    }

    /// Downloads paused until their disk has room.
    private(set) var waiting: Set<String>
    private let defaults: UserDefaults
    private static let key = "downloadsWaitingForSpace"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        waiting = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    /// Decides what to pause and resume.
    /// - Parameters:
    ///   - enabled: whether the setting is on; turning it off resumes everything it paused.
    ///   - volumes: the disk of each unfinished download's save folder.
    func evaluate(_ torrents: [Torrent], enabled: Bool, volumes: [String: DiskSpace.Volume]) -> Decision {
        defer { defaults.set(waiting.sorted(), forKey: Self.key) }
        // Forget downloads that were removed, finished or started again elsewhere.
        let byHash = Dictionary(torrents.map { ($0.hash, $0) }, uniquingKeysWith: { $1 })
        waiting = waiting.filter { byHash[$0].map { !$0.isComplete && $0.state.isStopped } ?? false }

        var decision = Decision()
        guard enabled else {
            decision.resume = waiting.sorted()
            waiting = []
            return decision
        }
        var fullDisks: Set<String> = []
        for torrent in torrents where !torrent.isComplete {
            guard let disk = volumes[torrent.savePath] else { continue }
            if disk.available < DiskSpace.reserve {
                if !torrent.state.isStopped {
                    decision.pause.append(torrent.hash)
                    waiting.insert(torrent.hash)
                }
            } else if disk.available >= DiskSpace.resumeAt, waiting.contains(torrent.hash) {
                decision.resume.append(torrent.hash)
                waiting.remove(torrent.hash)
            }
            if waiting.contains(torrent.hash) {
                fullDisks.insert(disk.name)
            }
        }
        decision.fullDisks = fullDisks.sorted()
        return decision
    }
}
