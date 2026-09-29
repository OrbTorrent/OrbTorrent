import SwiftUI

/// The actions for one download as a row of equal buttons, always in the same
/// order so they stay where people expect them.
///
/// The inspector shows them as tiles with Open and Remove; the menu bar panel
/// shows small capsules with "Show in OrbTorrent", then a round Delete.
struct TorrentActionButtons: View {
    enum Placement {
        case inspector, menuBar
    }

    @Environment(AppModel.self) private var model
    let torrent: Torrent
    let placement: Placement
    /// Asks to delete the download and its files, in the menu bar panel.
    var onDelete: (() -> Void)?

    var body: some View {
        switch placement {
        case .inspector:
            buttons.buttonStyle(.tile)
        case .menuBar:
            buttons.buttonStyle(.glassCapsule)
        }
    }

    private var buttons: some View {
        HStack(spacing: placement == .inspector ? 8 : 6) {
            let stopped = torrent.state.isStopped
            Button(stopped ? "Resume" : "Pause", systemImage: stopped ? "play.fill" : "pause.fill") {
                Task { await model.store.togglePause([torrent]) }
            }
            .help(stopped ? "Resume this download" : "Pause this download")

            // In the panel, Finder alone does: a folder download opens next to where Finder shows it.
            if placement == .inspector {
                Button("Open", systemImage: "arrow.up.forward.app") { FileActions.open(torrent) }
                    .help("Open the downloaded file or folder")
            }

            Button("Finder", systemImage: "folder") { FileActions.reveal(torrent) }
                .help("Show in Finder")

            switch placement {
            case .inspector:
                Button("Remove", systemImage: "trash", role: .destructive) {
                    model.requestRemoval(of: [torrent])
                }
                .help("Remove this download…")
            case .menuBar:
                Button("OrbTorrent", systemImage: "macwindow") {
                    model.showMainWindow(selecting: torrent.hash)
                }
                .help("Show in the OrbTorrent window")

                if let onDelete {
                    Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                        .buttonStyle(.glassIcon(diameter: 28))
                        .help("Delete this download and its files…")
                }
            }
        }
    }
}
