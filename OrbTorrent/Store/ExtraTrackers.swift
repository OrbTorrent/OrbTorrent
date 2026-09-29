import Foundation

/// Adds the public tracker list to public torrents, so they find more peers,
/// and remembers what it added so it can take it off again: when the setting
/// is turned off, when a tracker drops off the list, or when a magnet link
/// turns out to be a private torrent.
///
/// A torrent is known to be public once its files are known. Before that, a
/// magnet link counts as public only if all its trackers are plain public
/// ones: a private tracker's address carries a personal key.
@MainActor
final class ExtraTrackers {
    struct Change {
        let hash: String
        var add: [String] = []
        var remove: [String] = []
        fileprivate let situation: Situation
    }

    /// What a torrent is looked at again for, when any of it changes.
    fileprivate struct Situation: Equatable {
        let revision: Int
        let enabled: Bool
        let hasMetadata: Bool
        let isPrivate: Bool?
        let isComplete: Bool
    }

    /// The trackers OrbTorrent added to each torrent.
    private(set) var added: [String: Set<String>]
    /// Trackers a torrent came with because they were added to its magnet
    /// link to look it up, taken as added once the torrent is in the list.
    private var claimed: [String: Set<String>] = [:]
    private var lookedAt: [String: Situation] = [:]
    private var retryAt: [String: Date] = [:]
    /// Torrents removed outside OrbTorrent, such as by a sharing limit, are
    /// forgotten when the list next changes, once the engine has had time to
    /// load every torrent.
    private var prunedRevision = 0
    private let startedAt = Date.now
    private let defaults: UserDefaults
    private static let key = "addedTrackers"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: Self.key) as? [String: [String]] ?? [:]
        added = saved.mapValues(Set.init)
    }

    /// What to add and remove, for torrents that changed since they were last looked at.
    func changes(for torrents: [Torrent], list: [String], revision: Int, enabled: Bool) -> [Change] {
        let now = Date.now
        var changes: [Change] = []
        for torrent in torrents {
            let situation = Situation(revision: revision, enabled: enabled, hasMetadata: torrent.hasMetadata,
                                      isPrivate: torrent.isPrivate, isComplete: torrent.isComplete)
            guard lookedAt[torrent.hash] != situation || claimed[torrent.hash] != nil,
                  retryAt[torrent.hash].map({ now >= $0 }) ?? true
            else { continue }
            let change = change(for: torrent, list: list, enabled: enabled, situation: situation)
            if change.add.isEmpty && change.remove.isEmpty {
                lookedAt[torrent.hash] = situation
            } else {
                changes.append(change)
            }
        }
        let present = Set(torrents.map(\.hash))
        if lookedAt.count > torrents.count {
            lookedAt = lookedAt.filter { present.contains($0.key) }
        }
        if revision != prunedRevision, now.timeIntervalSince(startedAt) > 5 * 60 {
            prunedRevision = revision
            forget(added.keys.filter { !present.contains($0) })
        }
        return changes
    }

    private func change(for torrent: Torrent, list: [String], enabled: Bool, situation: Situation) -> Change {
        let current = torrent.trackerURLs
        var ours = added[torrent.hash] ?? []
        if let claim = claimed.removeValue(forKey: torrent.hash) {
            ours.formUnion(claim.intersection(current))
            record(ours, for: torrent.hash)
        }
        var change = Change(hash: torrent.hash, situation: situation)
        guard enabled, torrent.isPrivate != true else {
            change.remove = ours.sorted()
            return change
        }
        change.remove = ours.subtracting(list).sorted()
        let isPublic = torrent.isPrivate == false
            || (!torrent.hasMetadata && current.allSatisfy(TrackerList.isPublic))
        if isPublic && !torrent.isComplete {
            // One taken off by hand stays off.
            change.add = list.filter { !current.contains($0) && !ours.contains($0) }
        }
        return change
    }

    func didApply(_ change: Change) {
        var ours = added[change.hash] ?? []
        ours.formUnion(change.add)
        ours.subtract(change.remove)
        record(ours, for: change.hash)
        lookedAt[change.hash] = change.situation
        retryAt[change.hash] = nil
    }

    /// The engine may be restarting, or the torrent was just removed.
    func didFail(_ change: Change) {
        retryAt[change.hash] = .now.addingTimeInterval(30)
    }

    /// Trackers added to a magnet link to look it up, which the torrent keeps
    /// if it's added with the files its peers sent.
    func claim(_ trackers: [String], for hash: String) {
        guard !trackers.isEmpty else { return }
        claimed[hash, default: []].formUnion(trackers)
    }

    func forget(_ hashes: some Sequence<String>) {
        var changed = false
        for hash in hashes where added[hash] != nil {
            added[hash] = nil
            changed = true
        }
        if changed { save() }
    }

    private func record(_ trackers: Set<String>, for hash: String) {
        guard added[hash] != (trackers.isEmpty ? nil : trackers) else { return }
        added[hash] = trackers.isEmpty ? nil : trackers
        save()
    }

    private func save() {
        defaults.set(added.mapValues { $0.sorted() }, forKey: Self.key)
    }
}
