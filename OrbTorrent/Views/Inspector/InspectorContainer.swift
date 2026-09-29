import SwiftUI

/// Chooses what the inspector shows for the current selection.
struct InspectorContainer: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selected = model.store.selectedTorrents
        Group {
            if selected.count == 1, let torrent = selected.first {
                TorrentInspectorView(torrent: torrent)
                    .id(torrent.hash)
            } else if selected.count > 1 {
                MultipleSelectionView(torrents: selected)
            } else {
                ContentUnavailableView(
                    "No Selection",
                    systemImage: "sidebar.trailing",
                    description: Text("Select a download to see its files, peers and details.").font(.callout)
                )
            }
        }
        .inspectorColumnWidth(min: 320, ideal: 380, max: 560)
    }
}
