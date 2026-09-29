import Foundation

/// Pauses and resumes the engine has accepted but not reported yet.
///
/// The engine only refreshes the states it reports every so often, so a
/// download would go on looking active for a moment after Pause. Until the
/// engine catches up, the list shows it the way the person asked, for a few
/// seconds at most.
struct RequestedStates {
    /// How long to wait for the engine before believing it again.
    static let grace: TimeInterval = 5

    private var requests: [String: (stopped: Bool, until: Date)] = [:]

    mutating func request(stopped: Bool, for hashes: [String], now: Date = .now) {
        let until = now.addingTimeInterval(Self.grace)
        for hash in hashes { requests[hash] = (stopped, until) }
    }

    /// The downloads as the engine reports them, except any it hasn't caught
    /// up with yet. Forgets requests it has caught up with, or that expired.
    mutating func apply(to torrents: [Torrent], now: Date = .now) -> [Torrent] {
        requests = requests.filter { $0.value.until > now }
        guard !requests.isEmpty else { return torrents }
        var shown: [Torrent] = []
        shown.reserveCapacity(torrents.count)
        for torrent in torrents {
            guard let request = requests[torrent.hash] else {
                shown.append(torrent)
                continue
            }
            if torrent.state.isStopped == request.stopped {
                requests[torrent.hash] = nil
                shown.append(torrent)
            } else {
                shown.append(torrent.assuming(stopped: request.stopped))
            }
        }
        return shown
    }
}
