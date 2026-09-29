import SwiftUI

/// The files in a download, with per-file priorities and an optional
/// "download in this order" mode.
struct FilesTabView: View {
    let torrent: Torrent
    @State private var files: TorrentFilesModel

    init(torrent: Torrent, store: TorrentStore) {
        self.torrent = torrent
        _files = State(initialValue: TorrentFilesModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            if files.hasLoaded, !files.files.isEmpty {
                FileListHeader(files: files)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                Divider()
            }
            content
        }
        .task(id: torrent.hash) {
            await files.track(torrent.hash)
        }
    }

    @ViewBuilder
    private var content: some View {
        if !files.hasLoaded {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if files.files.isEmpty {
            emptyState
        } else {
            fileList
        }
    }

    private var emptyState: some View {
        let fetching = torrent.state.activity == .fetchingMetadata
        let title = fetching ? "Getting File List" : "No Files"
        let detail = fetching ? "The file list appears once peers send the torrent's details." : (files.loadError ?? "")
        return ContentUnavailableView(title, systemImage: "doc.questionmark", description: Text(detail).font(.callout))
            .frame(maxHeight: .infinity)
    }

    private var fileList: some View {
        let moveAction: ((IndexSet, Int) -> Void)? = files.isOrdering ? { files.move(from: $0, to: $1) } : nil
        return List {
            ForEach(files.displayedFiles) { file in
                FileRowView(file: file, torrent: torrent, files: files)
                    .listRowSeparator(.hidden)
                    // Line the checkboxes up with the select-all checkbox above.
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
            }
            .onMove(perform: moveAction)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, FileRowView.height + 2)
    }
}
