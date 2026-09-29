import SwiftUI

extension TorrentState.Activity {
    var tint: Color {
        switch self {
        case .downloading: .accentColor
        case .seeding, .completed: .green
        case .stopped: .secondary
        case .checking: .orange
        case .queued: .indigo
        case .stalled: .orange
        case .fetchingMetadata: .teal
        case .moving: .purple
        case .error: .red
        }
    }
}

extension ConnectionProblem {
    var tint: Color {
        switch self {
        case .engineOffline, .offline: .red
        case .incomingBlocked: .orange
        }
    }
}

extension StatusProblem {
    var tint: Color {
        switch self {
        case .diskAlmostFull, .waitingForVPN: .orange
        case .connection(let problem): problem.tint
        }
    }
}

extension Torrent {
    var tint: Color { state.activity.tint }

    /// Bytes of the selected files that are already on disk.
    var downloadedSize: Int64 { max(size - amountLeft, 0) }

    /// One line describing what is happening, e.g.
    /// "Downloading · 4.2 GB of 10.8 GB · 12m left".
    var statusLine: String { statusLine(waitingForSpace: false) }

    /// The status line of a download that may be paused until its disk has room.
    func statusLine(waitingForSpace: Bool) -> String {
        // Unknown until a magnet link's details arrive.
        let of: String? = size > 0 ? "\(Format.bytes(downloadedSize)) of \(Format.bytes(size))" : nil
        func line(_ parts: String?...) -> String { parts.compactMap { $0 }.joined(separator: " · ") }
        switch state.activity {
        case .downloading:
            return line("Downloading", of, Format.eta(eta).map { "\($0) left" })
        case .stalled:
            return line("Waiting for peers", of)
        case .fetchingMetadata:
            return "Getting file list from peers"
        case .checking:
            return "Checking files · \(Format.percent(progress))"
        case .queued:
            return line("Queued", of)
        case .moving:
            return "Moving files"
        case .stopped:
            return line(waitingForSpace ? "Waiting for disk space" : "Paused", of)
        case .seeding:
            return "Seeding · \(Format.bytes(size)) · Ratio \(Format.ratio(ratio))"
        case .completed:
            let when = completedOn.map { " · \($0.formatted(.relative(presentation: .named)))" } ?? ""
            return "Completed · \(Format.bytes(size))\(when)"
        case .error:
            return state.title
        }
    }

    /// Short live figure shown at the end of the name line.
    var liveFigure: String {
        switch state.activity {
        case .downloading, .stalled, .fetchingMetadata:
            downloadSpeed > 0 ? "↓ \(Format.speed(downloadSpeed))" : Format.percent(progress)
        case .seeding:
            uploadSpeed > 0 ? "↑ \(Format.speed(uploadSpeed))" : ""
        case .checking, .queued, .stopped:
            Format.percent(progress)
        case .completed, .moving, .error:
            ""
        }
    }
}
