import Foundation

extension Torrent {
    var orbState: OrbState {
        switch state.activity {
        case .downloading: .downloading(progress: progress, energy: OrbState.energy(forSpeed: downloadSpeed))
        case .stalled, .checking, .queued, .fetchingMetadata, .moving: .waiting(progress: progress)
        case .stopped: .paused(progress: progress)
        case .seeding: .seeding
        case .completed: .finished
        case .error: .failed(progress: progress)
        }
    }
}

extension OrbState {
    /// Every download at a glance: downloading while anything is moving,
    /// otherwise the most telling of the rest: an error, then seeding, then
    /// downloads waiting for peers, then paused ones.
    ///
    /// The level follows only the downloads that are moving, so one that's
    /// stuck waiting for peers doesn't hold back the rest.
    static func overall(of torrents: [Torrent], moving: Set<String>, downloadSpeed: Int64) -> OrbState {
        let unfinished = torrents.filter { !$0.isComplete }
        let downloading = unfinished.filter { moving.contains($0.hash) }
        if !downloading.isEmpty {
            return .downloading(progress: progress(of: downloading), energy: energy(forSpeed: downloadSpeed))
        }
        let failed = torrents.filter { $0.state.activity == .error }
        if !failed.isEmpty { return .failed(progress: progress(of: failed)) }
        if torrents.contains(where: { $0.state.activity == .seeding }) { return .seeding }
        let waiting = unfinished.filter { !$0.state.isStopped }
        if !waiting.isEmpty { return .waiting(progress: progress(of: waiting)) }
        if !unfinished.isEmpty { return .paused(progress: progress(of: unfinished)) }
        return torrents.isEmpty ? .idle : .finished
    }

    /// The share of the downloads' bytes already on disk.
    private static func progress(of torrents: [Torrent]) -> Double {
        let size = torrents.reduce(0) { $0 + $1.size }
        // Magnet links have no size until their details arrive.
        guard size > 0 else { return torrents.reduce(0) { $0 + $1.progress } / Double(max(torrents.count, 1)) }
        return Double(torrents.reduce(0) { $0 + $1.downloadedSize }) / Double(size)
    }
}

extension TorrentStore {
    var orbState: OrbState {
        .overall(of: torrents, moving: movingDownloads, downloadSpeed: transfer.downloadSpeed)
    }

    /// One download's orb, which stays downloading through a brief stall.
    func orbState(for torrent: Torrent) -> OrbState {
        if movingDownloads.contains(torrent.hash), torrent.state.activity == .stalled {
            return .downloading(progress: torrent.progress, energy: 0)
        }
        return torrent.orbState
    }
}

extension AppModel {
    /// The orb for the app as a whole, including the engine's own health.
    var orbState: OrbState {
        switch engine.status {
        case .running: store.orbState
        case .starting: .waiting(progress: 1)
        case .stopped, .failed: .failed(progress: 1)
        }
    }
}
