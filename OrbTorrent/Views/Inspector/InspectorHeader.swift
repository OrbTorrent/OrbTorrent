import SwiftUI

/// Name, progress and the main actions for the inspected download.
///
/// The orb shows the progress; the lines beside it give the exact figures.
struct InspectorHeader: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                LiveOrb(state: model.store.orbState(for: torrent))
                    .frame(width: 56, height: 56)
                    // Each download's orb starts fresh rather than easing from the last one's.
                    .id(torrent.hash)
                VStack(alignment: .leading, spacing: 3) {
                    Text(torrent.name)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    Text(statusText)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(torrent.state.activity == .error ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TorrentActionButtons(torrent: torrent, placement: .inspector)
        }
    }

    /// Everything about the download in one line, e.g.
    /// "Downloading · 23% · 680 MB of 2.93 GB · ↓ 32.6 MB/s · 2 min left".
    private var statusText: String {
        var parts = [torrent.state.title]
        // Unknown until a magnet link's details arrive.
        if torrent.size > 0 {
            if torrent.isComplete {
                parts.append(Format.bytes(torrent.size))
            } else {
                parts.append(Format.percent(torrent.progress))
                parts.append("\(Format.bytes(torrent.downloadedSize)) of \(Format.bytes(torrent.size))")
            }
        }
        // Live figures, while there are any.
        switch torrent.state.activity {
        case .downloading:
            parts.append("↓ \(Format.speed(torrent.downloadSpeed))")
            if let eta = Format.eta(torrent.eta) { parts.append("\(eta) left") }
        case .seeding:
            parts.append("↑ \(Format.speed(torrent.uploadSpeed))")
            parts.append("Ratio \(Format.ratio(torrent.ratio))")
        default:
            break
        }
        return parts.joined(separator: " · ")
    }
}
