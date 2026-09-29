import SwiftUI

/// One file inside a download, used by the inspector and the menu bar panel.
///
/// Rows have a fixed height, so a row never changes size. The circle at the end
/// shows the file's priority, or a tick once it's done, and opens a menu.
struct FileRowView: View {
    let file: TorrentFile
    let torrent: Torrent
    let files: TorrentFilesModel
    /// Opens the file on a single click instead of a double click.
    var opensOnClick = false

    /// Every file row has this height; lists use it for their minimum row height.
    static let height: CGFloat = 42

    @State private var isHovering = false

    private var position: Int? { files.position(of: file) }
    private var isOrdering: Bool { files.isOrdering }
    private var canOpen: Bool { file.progress > 0 }

    var body: some View {
        HStack(spacing: 8) {
            // Nothing left to choose once every file is downloaded.
            if !files.isAllDownloaded {
                Toggle("Download", isOn: Binding(
                    get: { file.isWanted },
                    set: { files.setWanted($0, for: [file]) }
                ))
                .toggleStyle(.checkbox)
                .labelsHidden()
            }

            if isOrdering {
                Text(position.map(String.init) ?? "–")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(position == 1 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .frame(width: 16)
            }

            Image(systemName: file.kind.symbol)
                .font(.system(size: 14))
                .foregroundStyle(file.isWanted ? .secondary : .tertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(file.isWanted ? .primary : .secondary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.head)
                if file.isWanted && !file.isComplete {
                    ProgressCapsule(value: file.progress, height: 3)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FileStateMenu(file: file, torrent: torrent, files: files)
                .frame(width: 28)

            if isOrdering {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
                    .help("Drag to reorder")
                    .accessibilityHidden(true)
            }
        }
        .frame(height: Self.height)
        .padding(.horizontal, opensOnClick ? PanelGrid.cardPadding : 0)
        .contentShape(.rect)
        .background(opensOnClick && isHovering && canOpen ? AnyShapeStyle(.quaternary.opacity(0.6)) : AnyShapeStyle(.clear),
                    in: .rect(cornerRadius: 8))
        .onHover { isHovering = $0 }
        .onTapGesture(count: opensOnClick ? 1 : 2) {
            if canOpen { FileActions.open(file, in: torrent) }
        }
        .contextMenu { contextMenu }
        .help(file.name)
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Open", systemImage: "arrow.up.forward.app") { FileActions.open(file, in: torrent) }
            .disabled(!canOpen)
        Button("Show in Finder", systemImage: "folder") { FileActions.reveal(file, in: torrent) }
        if !files.isAllDownloaded {
            fileChoices
        }
    }

    @ViewBuilder
    private var fileChoices: some View {
        Divider()
        if isOrdering {
            if file.isWanted, !file.isComplete {
                Button("Download This Next", systemImage: "arrow.up.to.line") { files.downloadNext(file) }
            }
        } else {
            Menu("Priority") { FilePriorityPicker(file: file, files: files) }
        }
        Divider()
        Button("Download All Files") { files.setAllWanted(true) }
        Button("Skip All Files") { files.setAllWanted(false) }
    }

    private var detail: String {
        var parts: [String] = []
        if let subfolder { parts.append(subfolder) }
        if !file.isWanted || file.isComplete {
            parts.append(Format.bytes(file.size))
        } else {
            let done = Int64(Double(file.size) * file.progress)
            parts.append("\(Format.bytes(done)) of \(Format.bytes(file.size)) · \(Format.percent(file.progress))")
        }
        return parts.joined(separator: " · ")
    }

    /// The folder inside the torrent, without the torrent's own root folder.
    private var subfolder: String? {
        guard let folder = file.folder else { return nil }
        let components = folder.split(separator: "/")
        guard components.count > 1 else { return nil }
        return components.dropFirst().joined(separator: " › ")
    }
}
