import SwiftUI

/// Shown when the current list has nothing in it.
struct EmptyLibraryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.store
        if !store.searchText.isEmpty {
            ContentUnavailableView.search(text: store.searchText)
        } else if store.filter != .all {
            ContentUnavailableView {
                Label("Nothing \(store.filter.title)", systemImage: store.filter.symbol)
            } description: {
                Text("Downloads appear here when they're \(store.filter.title.lowercased()).")
                    .font(.callout)
            }
        } else {
            ContentUnavailableView {
                Label("No Downloads Yet", systemImage: "arrow.down.circle.dotted")
            } description: {
                Text("Click a magnet link in your browser, open a .torrent file, or drop one here.")
                    .font(.callout)
            } actions: {
                HStack(spacing: 10) {
                    Button("Add Magnet Link…") { model.adder.presentMagnetSheet() }
                        .buttonStyle(.glass)
                    Button("Open Torrent File…") { model.adder.presentOpenPanel() }
                        .buttonStyle(.glassProminent)
                }
                .controlSize(.large)
            }
        }
    }
}
