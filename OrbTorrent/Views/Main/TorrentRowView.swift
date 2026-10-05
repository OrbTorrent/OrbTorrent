import SwiftUI

/// One download in the library list.
///
/// Every row has the same three lines and a fixed height; actions live in the
/// context menu, toolbar and inspector rather than on hover.
struct TorrentRowView: View {
    /// The height of every row in the list, padding included. The list uses it
    /// as its minimum row height: macOS lists sometimes never measure rows
    /// inserted while they're on screen, and would otherwise leave them
    /// squashed at the default height.
    static let rowHeight: CGFloat = 60
    /// The content's fixed height, leaving room for the list's own row padding.
    private static let contentHeight: CGFloat = 50

    let torrent: Torrent
    @Environment(AppModel.self) private var model
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        HStack(spacing: 12) {
            TorrentIcon(symbol: torrent.kind.symbol, tint: torrent.tint, size: 34)
                .checkBadge { CheckRingButton(torrent: torrent) }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    DownloadNameText(name: torrent.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 8)
                    Text(torrent.liveFigure)
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                }

                ProgressCapsule(value: torrent.progress, tint: torrent.tint, height: 4)

                Text(model.store.statusLine(of: torrent))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(statusStyle)
                    .lineLimit(1)
            }
        }
        .frame(height: Self.contentHeight)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var statusStyle: AnyShapeStyle {
        if model.extensions.isOn && model.extensions.checks.gate(for: torrent.hash) == .held && prominence != .increased {
            return AnyShapeStyle(.orange)
        }
        if torrent.state.activity == .error && prominence != .increased {
            return AnyShapeStyle(.red)
        }
        return AnyShapeStyle(.secondary)
    }
}
