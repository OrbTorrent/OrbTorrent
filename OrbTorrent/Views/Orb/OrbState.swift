import Foundation

/// What an orb shows: one download, or everything at a glance.
enum OrbState: Equatable {
    /// Nothing happening: the resting logo.
    case idle
    /// `energy` is how fast it's going, 0...1.
    case downloading(progress: Double, energy: Double)
    /// Stalled, checking, queued, moving files, or fetching a magnet link's details.
    case waiting(progress: Double)
    case paused(progress: Double)
    case seeding
    case finished
    case failed(progress: Double)

    var isFinished: Bool {
        switch self {
        case .seeding, .finished: true
        default: false
        }
    }

    /// How full the orb is, 0...1.
    var progress: Double {
        switch self {
        case .idle, .seeding, .finished: 1
        case .downloading(let progress, _), .waiting(let progress), .paused(let progress), .failed(let progress):
            progress
        }
    }

    /// How lively a download speed looks: calm below 50 KB/s, full energy from 20 MB/s.
    static func energy(forSpeed bytesPerSecond: Int64) -> Double {
        guard bytesPerSecond > 50_000 else { return 0 }
        return min(1, log2(Double(bytesPerSecond) / 50_000) / log2(400))
    }
}
