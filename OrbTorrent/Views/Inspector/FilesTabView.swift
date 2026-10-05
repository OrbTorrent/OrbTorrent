import SwiftUI

/// The files in a download, with per-file priorities and an optional
/// "download in this order" mode. Files can be selected, to open or change
/// several at once.
struct FilesTabView: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    @State private var files: TorrentFilesModel
    @State private var selection = Set<TorrentFile.ID>()

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
        .onChange(of: torrent.hash) { selection = [] }
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
        let problems = model.extensions.fileProblems(of: torrent.hash)
        let names = model.settings.shownFileNames(of: files.files)
        return List(selection: $selection) {
            ForEach(files.displayedFiles) { file in
                FileRowView(file: file, torrent: torrent, files: files, shownName: names[file.index],
                            problems: problems[file.index] ?? [])
                    .listRowSeparator(.hidden)
                    // Line the checkboxes up with the select-all checkbox above.
                    .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
            }
            .onMove(perform: moveAction)
        }
        // Rounded highlights, like the list of downloads.
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, FileRowView.height + 2)
        // For the files right-clicked: the selection, or the one clicked outside it.
        .contextMenu(forSelectionType: TorrentFile.ID.self) { ids in
            let targets = files.displayedFiles.filter { ids.contains($0.id) }
            if !targets.isEmpty {
                FileContextMenu(targets: targets, torrent: torrent, files: files)
            }
        } primaryAction: { ids in
            // Double-click or Return.
            for file in files.displayedFiles where ids.contains(file.id) && file.progress > 0 {
                FileActions.open(file, in: torrent)
            }
        }
    }
}
