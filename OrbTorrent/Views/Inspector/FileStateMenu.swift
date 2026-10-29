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
        isDone ? .green : file.priority.color
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
        return file.priority.help
    }
}

extension FilePriority {
    /// Raised priorities stand out.
    var color: Color {
        switch self {
        case .skip, .normal: .secondary
        case .high, .maximum: .orange
        }
    }

    var help: String {
        self == .skip ? "Not downloading" : "\(title) priority"
    }
}

/// The four priorities as a checkable list, for menus.
struct FilePriorityPicker: View {
    /// The one ticked; none is when the files it's for differ.
    let selection: FilePriority?
    let choose: (FilePriority) -> Void

    var body: some View {
        Picker("Priority", selection: Binding<FilePriority?>(
            get: { selection },
            set: { priority in
                if let priority { choose(priority) }
            }
        )) {
            ForEach(FilePriority.allCases) { priority in
                Label(priority.title, systemImage: priority.symbol).tag(FilePriority?.some(priority))
            }
        }
        .pickerStyle(.inline)
    }
}

extension FilePriorityPicker {
    /// For files in the library: ticked when every file has it.
    init(targets: [TorrentFile], files: TorrentFilesModel) {
        self.init(selection: Set(targets.map(\.priority)).count == 1 ? targets.first?.priority : nil) { priority in
            files.setPriority(priority, for: targets.filter { $0.priority != priority })
        }
    }
}
