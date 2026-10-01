import SwiftUI

/// The circle at the end of a file row: the file's state at a glance, and a
/// menu to change it.
///
/// Every state uses the same circle family — a tick once the file is done,
/// otherwise its priority — so a list of files reads at a glance.
struct FileStateMenu: View {
    let file: TorrentFile
    let torrent: Torrent
    let files: TorrentFilesModel

    private var isDone: Bool { file.isWanted && file.isComplete }
    private var position: Int? { files.position(of: file) }

    var body: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: isDone ? "checkmark.circle.fill" : file.priority.symbol)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .tint(color)
        .help(helpText)
        .accessibilityLabel(helpText)
    }

    @ViewBuilder
    private var menuItems: some View {
        if isDone {
            Button("Open", systemImage: "arrow.up.forward.app") { FileActions.open(file, in: torrent) }
            Button("Show in Finder", systemImage: "folder") { FileActions.reveal(file, in: torrent) }
        } else if files.isOrdering && file.isWanted {
            // OrbTorrent assigns priorities itself in this mode; offer order changes instead.
            Button("Download This Next", systemImage: "arrow.up.to.line") { files.downloadNext(file) }
                .disabled(position == 1)
            Button("Don't Download", systemImage: FilePriority.skip.symbol) { files.setWanted(false, for: [file]) }
        } else {
            FilePriorityPicker(targets: [file], files: files)
        }
    }

    private var color: Color {
        if isDone { return .green }
        return switch file.priority {
        case .skip, .normal: .secondary
        case .high, .maximum: .orange
        }
    }

    private var helpText: String {
        if isDone { return "Finished" }
        if files.isOrdering, file.isWanted, let position {
            return switch position {
            case 1: "Downloading first"
            case 2: "Downloading next"
            default: "Number \(position) in the download order"
            }
        }
        return file.isWanted ? "\(file.priority.title) priority" : "Not downloading"
    }
}

/// The four priorities as a checkable list, for menus.
struct FilePriorityPicker: View {
    let targets: [TorrentFile]
    let files: TorrentFilesModel

    var body: some View {
        // Ticked when every file has it; none is when they differ.
        Picker("Priority", selection: Binding<FilePriority?>(
            get: { Set(targets.map(\.priority)).count == 1 ? targets.first?.priority : nil },
            set: { priority in
                if let priority { files.setPriority(priority, for: targets.filter { $0.priority != priority }) }
            }
        )) {
            ForEach(FilePriority.allCases) { priority in
                Label(priority.title, systemImage: priority.symbol).tag(FilePriority?.some(priority))
            }
        }
        .pickerStyle(.inline)
    }
}
