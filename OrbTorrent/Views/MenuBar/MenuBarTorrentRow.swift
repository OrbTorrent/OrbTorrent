import SwiftUI

/// A compact download row for the menu bar panel. Clicking it shows the
/// download's files; the round button pauses, resumes or opens it, a
/// Delete button appears beside it on hover, and a right click shows the rest.
struct MenuBarTorrentRow: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    /// Whether the row is asking to delete the download, in its place.
    @Binding var isConfirmingDelete: Bool
    let onSelect: () -> Void
    @State private var isHovering = false

    var body: some View {
        if isConfirmingDelete {
            MenuBarDeleteConfirmation(torrent: torrent) {
                isConfirmingDelete = false
            } onDelete: {
                await model.delete([torrent])
            }
            .padding(.horizontal, PanelGrid.boxPadding)
            .padding(.vertical, 8)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 12))
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 10) {
            TorrentIcon(symbol: torrent.kind.symbol, tint: torrent.tint, size: 32)
                .checkBadge {
                    let summary = model.extensions.summary(of: torrent)
                    if !summary.isEmpty {
                        // Clicking the row shows the checks, so the ring is only a sign here.
                        CheckRingBadge(summary: summary)
                            .help(summary.title)
                    }
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(torrent.name)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                ProgressCapsule(value: torrent.progress, tint: torrent.tint, height: 4)
                Text(model.store.statusLine(of: torrent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            if isHovering {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    isConfirmingDelete = true
                }
                .buttonStyle(.glassIcon)
                .help("Delete this download and its files…")
            }
            actionButton
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, PanelGrid.boxPadding)
        .padding(.vertical, 8)
        .contentShape(.rect(cornerRadius: 12))
        .background(isHovering ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear),
                    in: .rect(cornerRadius: 12))
        .onHover { isHovering = $0 }
        .onTapGesture(perform: onSelect)
        .contextMenu { contextMenu }
        .help("Show files")
        // The Delete button only shows on hover.
        .accessibilityAction(named: "Delete…") { isConfirmingDelete = true }
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Open", systemImage: "arrow.up.forward.app") { FileActions.open(torrent) }
        Button("Show in Finder", systemImage: "folder") { FileActions.reveal(torrent) }
        Divider()
        let stopped = torrent.state.isStopped
        Button(stopped ? "Resume" : "Pause", systemImage: stopped ? "play" : "pause") {
            Task { await model.store.togglePause([torrent]) }
        }
        Button("Copy Magnet Link", systemImage: "link") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(torrent.magnetURI, forType: .string)
        }
        Button("Show in OrbTorrent", systemImage: "macwindow") {
            model.showMainWindow(selecting: torrent.hash)
        }
        Divider()
        Button("Delete…", systemImage: "trash", role: .destructive) {
            isConfirmingDelete = true
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if torrent.isComplete {
            Button("Open", systemImage: "arrow.up.forward") { FileActions.open(torrent) }
                .buttonStyle(.glassIcon)
                .help("Open")
        } else {
            let stopped = torrent.state.isStopped
            Button(stopped ? "Resume" : "Pause", systemImage: stopped ? "play.fill" : "pause.fill") {
                Task { await model.store.togglePause([torrent]) }
            }
            .buttonStyle(.glassIcon)
            .help(stopped ? "Resume" : "Pause")
        }
    }
}
