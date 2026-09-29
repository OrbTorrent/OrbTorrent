import AppKit
import SwiftUI

/// One download inside the menu bar panel: its controls and its files, so
/// priorities can be set and files opened without the main window.
struct MenuBarTorrentDetail: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    let onBack: () -> Void
    @State private var files: TorrentFilesModel
    @State private var isConfirmingDelete = false
    /// Whether the user opened the checks card. It starts closed: its ring
    /// and tinted edge already say how the checks went.
    @State private var checksOpened = false

    /// The file list scrolls beyond this height.
    private let maxListHeight: CGFloat = 330
    /// Each list row: the file row plus its 1 pt top and bottom inset.
    private let rowHeight = FileRowView.height + 2

    init(torrent: Torrent, store: TorrentStore, onBack: @escaping () -> Void) {
        self.torrent = torrent
        self.onBack = onBack
        _files = State(initialValue: TorrentFilesModel(store: store))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The title starts where text after a download's icon does.
            HStack(alignment: .center, spacing: PanelGrid.largeText - 28) {
                Button("Back", systemImage: "chevron.left", action: onBack)
                    .buttonStyle(.glassIcon)
                    .keyboardShortcut(.cancelAction)
                    .help("Back to downloads")
                VStack(alignment: .leading, spacing: 2) {
                    Text(torrent.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(model.store.statusLine(of: torrent))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }

            ProgressCapsule(value: torrent.progress, tint: torrent.tint, height: 5)

            if isConfirmingDelete {
                MenuBarDeleteConfirmation(torrent: torrent) {
                    isConfirmingDelete = false
                } onDelete: {
                    // The panel goes back to the list once the download is gone.
                    await model.delete([torrent])
                }
            } else {
                TorrentActionButtons(torrent: torrent, placement: .menuBar) {
                    isConfirmingDelete = true
                }
            }

            let summary = model.extensions.summary(of: torrent)
            if !summary.isEmpty {
                ChecksCard(summary: summary, isOpen: checksOpenBinding(summary), torrent: torrent)
            }

            filesSection
        }
        .task(id: torrent.hash) {
            await files.track(torrent.hash)
        }
    }

    @ViewBuilder
    private var filesSection: some View {
        if !files.hasLoaded {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else if files.files.isEmpty {
            Text(torrent.state.activity == .fetchingMetadata
                 ? "The file list appears once peers send the torrent's details."
                 : "No files.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // In line with the rows' contents, which are padded like the card's.
                FileListHeader(files: files)
                    .padding(.horizontal, PanelGrid.cardPadding)
                Divider()
                fileList
            }
        }
    }

    /// Open when the user opened it. A held download's card stays open, as
    /// nothing downloads until the user decides.
    private func checksOpenBinding(_ summary: CheckSummary) -> Binding<Bool> {
        Binding(
            get: { summary.isHeld || checksOpened },
            set: { checksOpened = $0 }
        )
    }

    /// The file list is shorter while the checks card is open, so the panel
    /// doesn't grow past the screen.
    private var listHeightLimit: CGFloat {
        let summary = model.extensions.summary(of: torrent)
        return !summary.isEmpty && checksOpenBinding(summary).wrappedValue ? 200 : maxListHeight
    }

    /// A native list, so files can be dragged into order like in the inspector.
    private var fileList: some View {
        let moveAction: ((IndexSet, Int) -> Void)? = files.isOrdering ? { files.move(from: $0, to: $1) } : nil
        return List {
            ForEach(files.displayedFiles) { file in
                FileRowView(file: file, torrent: torrent, files: files, opensOnClick: true)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
            }
            .onMove(perform: moveAction)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, rowHeight)
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(CGFloat(files.files.count) * rowHeight, listHeightLimit))
        // The list keeps an 8 pt margin of its own. Cancelling it puts the
        // rows' edges on the card's, with their contents padded like the
        // card's. A scroll bar that takes up room keeps the right margin, so
        // it stays inside the panel's right edge.
        .padding(.leading, -8)
        .padding(.trailing, NSScroller.preferredScrollerStyle == .legacy ? 0 : -8)
    }
}
