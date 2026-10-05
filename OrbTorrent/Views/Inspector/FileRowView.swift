import SwiftUI

/// One file inside a download, used by the inspector and the menu bar panel.
///
/// Rows have a fixed height, so a row never changes size. The circle at the end
/// shows the file's priority, or a tick once it's done, and opens a menu.
struct FileRowView: View {
    let file: TorrentFile
    let torrent: Torrent
    let files: TorrentFilesModel
    /// In the menu bar panel, a click opens the file and the row has its own
    /// menu. In the inspector, the list selects rows, and opens and shows the
    /// menu for the selected files.
    var opensOnClick = false
    /// What checks found wrong with it, worst first.
    var problems: [FileFinding] = []

    /// Every file row has this height; lists use it for their minimum row height.
    static let height: CGFloat = 42

    @State private var isHovering = false

    private var position: Int? { files.position(of: file) }
    private var isOrdering: Bool { files.isOrdering }
    private var canOpen: Bool { file.progress > 0 }

    var body: some View {
        if opensOnClick {
            row
                .onTapGesture {
                    if canOpen { FileActions.open(file, in: torrent) }
                }
                .rightClickMenu {
                    FileContextMenu(targets: [file], torrent: torrent, files: files)
                } onOpenChange: { isOpen, pointerInside in
                    isHovering = isOpen || pointerInside
                }
        } else {
            row
        }
    }

    private var row: some View {
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
                HStack(spacing: 5) {
                    Text(file.fileName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(file.isWanted ? .primary : .secondary)
                    if let worst = problems.first {
                        CheckStatusIcon(status: worst.result.status, size: 12, help: problems.map(\.line).joined(separator: "\n"))
                            .accessibilityLabel(worst.line)
                    }
                }
                if let worst = problems.first {
                    // What a check found matters more than the size.
                    Text(worst.reason)
                        .font(.caption)
                        .foregroundStyle(worst.result.status == .failed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .truncationMode(.tail)
                } else {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .truncationMode(.head)
                }
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
        .help(([file.name] + problems.map(\.line)).joined(separator: "\n"))
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

/// What can be done to one or more files: a file row's menu in the menu bar
/// panel, or the menu for the files selected in the inspector.
struct FileContextMenu: View {
    let targets: [TorrentFile]
    let torrent: Torrent
    let files: TorrentFilesModel

    var body: some View {
        let openable = targets.filter { $0.progress > 0 }
        Button("Open", systemImage: "arrow.up.forward.app") {
            for file in openable { FileActions.open(file, in: torrent) }
        }
        .disabled(openable.isEmpty)
        Button("Show in Finder", systemImage: "folder") { FileActions.reveal(targets, in: torrent) }
        // Nothing left to choose once every file is downloaded.
        if !files.isAllDownloaded {
            choices
        }
    }

    @ViewBuilder
    private var choices: some View {
        Divider()
        // One file has its own checkbox; several are quicker from here.
        if targets.count > 1 {
            let skipped = targets.filter { !$0.isWanted }
            let wanted = targets.filter(\.isWanted)
            if !skipped.isEmpty {
                Button("Download \(Format.count(skipped.count, "File"))") { files.setWanted(true, for: skipped) }
            }
            if !wanted.isEmpty {
                Button("Skip \(Format.count(wanted.count, "File"))") { files.setWanted(false, for: wanted) }
            }
        }
        if files.isOrdering {
            if targets.count == 1, let file = targets.first, file.isWanted, !file.isComplete {
                Button("Download This Next", systemImage: "arrow.up.to.line") { files.downloadNext(file) }
            }
        } else {
            Menu("Priority") { FilePriorityPicker(targets: targets, files: files) }
        }
        Divider()
        Button("Download All Files") { files.setAllWanted(true) }
        Button("Skip All Files") { files.setAllWanted(false) }
    }
}
