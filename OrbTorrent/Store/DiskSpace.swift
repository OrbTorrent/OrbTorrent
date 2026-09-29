import Foundation

/// Free space on the disks downloads are saved to.
///
/// Space is what macOS makes available for things the person asked for,
/// including space it can clear by itself, as Finder shows it.
enum DiskSpace {
    /// Space OrbTorrent leaves free for the Mac: downloads pause before a disk
    /// has less than this.
    static let reserve: Int64 = 5_000_000_000
    /// Paused downloads resume once their disk has this much free, a little
    /// more than the reserve, so they don't stop and start as space comes and goes.
    static let resumeAt: Int64 = 7_000_000_000

    /// A disk and its free space.
    struct Volume: Equatable, Sendable {
        /// The disk's root folder, which tells disks apart.
        let id: URL
        let name: String
        let available: Int64
    }

    /// An unfinished download, for counting what it still needs.
    struct Download: Sendable {
        let savePath: String
        let remaining: Int64
    }

    /// The disk a new download would be saved to, and what downloads already
    /// saving there still need.
    struct Room: Equatable, Sendable {
        let disk: String
        let available: Int64
        let othersNeed: Int64

        /// Whether a download needing this much fits, leaving the reserve free.
        func fits(_ needed: Int64) -> Bool {
            available - othersNeed - needed >= DiskSpace.reserve
        }
    }

    /// The disk a folder is on, or nil when it isn't connected. The folder
    /// needn't exist yet: the engine creates it.
    static func volume(containing path: String) -> Volume? {
        var url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        while !FileManager.default.fileExists(atPath: url.path) {
            let parent = url.deletingLastPathComponent()
            // A folder on an external disk that isn't connected would otherwise
            // be counted on the startup disk, which holds /Volumes.
            guard parent.path != url.path, parent.path != "/Volumes" else { return nil }
            url = parent
        }
        let keys: Set<URLResourceKey> = [.volumeURLKey, .volumeLocalizedNameKey,
                                         .volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey]
        guard let values = try? url.resourceValues(forKeys: keys), let root = values.volume else { return nil }
        // Disks that aren't APFS don't report space for important use.
        let available = values.volumeAvailableCapacityForImportantUsage.flatMap { $0 > 0 ? $0 : nil }
            ?? values.volumeAvailableCapacity.map(Int64.init)
        guard let available else { return nil }
        return Volume(id: root, name: values.volumeLocalizedName ?? root.lastPathComponent, available: available)
    }

    /// The disks of several folders, looking each one up once.
    static func volumes(for paths: Set<String>) -> [String: Volume] {
        var volumes: [String: Volume] = [:]
        for path in paths {
            volumes[path] = volume(containing: path)
        }
        return volumes
    }

    /// Room for a new download in a folder, given the unfinished downloads.
    static func room(forFolder folder: String, downloads: [Download]) -> Room? {
        guard let target = volume(containing: folder) else { return nil }
        let disks = volumes(for: Set(downloads.map(\.savePath)))
        let othersNeed = downloads
            .filter { disks[$0.savePath]?.id == target.id }
            .reduce(Int64(0)) { $0 + $1.remaining }
        return Room(disk: target.name, available: target.available, othersNeed: othersNeed)
    }
}
