import SwiftUI

/// The list of downloads for the selected sidebar section.
struct TorrentListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var store = model.store
        let torrents = store.visibleTorrents

        List(selection: $store.selection) {
            if let groups = model.settings.listGrouping.groups(of: torrents) {
                ForEach(groups) { group in
                    Section {
                        rows(group.torrents)
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            Text("\(group.torrents.count)")
                                .monospacedDigit()
                        }
                    }
                }
            } else {
                rows(torrents)
            }
        }
        .listStyle(.inset)
        .environment(\.defaultMinListRowHeight, TorrentRowView.rowHeight)
        .contextMenu(forSelectionType: String.self) { hashes in
            let targets = store.torrents.filter { hashes.contains($0.hash) }
            if !targets.isEmpty {
                TorrentContextMenu(torrents: targets)
            }
        } primaryAction: { hashes in
            for torrent in store.torrents where hashes.contains(torrent.hash) {
                FileActions.open(torrent)
            }
        }
        .onDeleteCommand {
            model.requestRemoval(of: store.selectedTorrents)
        }
        .overlay {
            if torrents.isEmpty && store.hasLoaded {
                EmptyLibraryView()
            }
        }
        .navigationTitle(store.filter.title)
        .navigationSubtitle(subtitle(for: torrents))
    }

    private func rows(_ torrents: [Torrent]) -> some View {
        ForEach(torrents) { torrent in
            TorrentRowView(torrent: torrent)
                .tag(torrent.hash)
        }
    }

    private func subtitle(for torrents: [Torrent]) -> String {
        guard !torrents.isEmpty else { return "" }
        let total = torrents.reduce(Int64(0)) { $0 + $1.size }
        return "\(Format.count(torrents.count, "item")) · \(Format.bytes(total))"
    }
}
