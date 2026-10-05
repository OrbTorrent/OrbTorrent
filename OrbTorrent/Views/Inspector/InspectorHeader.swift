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
                    DownloadNameText(name: torrent.name)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)
                    // Two lines that each stay one line, so the figures changing every
                    // second never wrap and move everything below up and down.
                    Group {
                        Text(statusText)
                            .foregroundStyle(torrent.state.activity == .error ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        if let liveText {
                            Text(liveText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                    .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            TorrentActionButtons(torrent: torrent, placement: .inspector)
        }
    }

    /// Where the download is, e.g. "Downloading · 23% · 680 MB of 2.93 GB".
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
        return parts.joined(separator: " · ")
    }

    /// The live figures, while there are any, e.g. "↓ 32.6 MB/s · 2 min left".
    private var liveText: String? {
        switch torrent.state.activity {
        case .downloading:
            ["↓ \(Format.speed(torrent.downloadSpeed))", Format.eta(torrent.eta).map { "\($0) left" }]
                .compactMap { $0 }.joined(separator: " · ")
        case .seeding:
            "↑ \(Format.speed(torrent.uploadSpeed)) · Ratio \(Format.ratio(torrent.ratio))"
        default:
            nil
        }
    }
}
