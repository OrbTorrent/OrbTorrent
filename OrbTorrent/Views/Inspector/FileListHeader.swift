import SwiftUI

/// The row above a file list: a select-all checkbox with the file count, and
/// the switch that makes files download one after another.
///
/// Once every file is downloaded there's nothing to choose or order, so it's
/// just the count. The switch shows only while there are at least two files
/// left to put in order, or while it's on, so it can be switched off.
struct FileListHeader: View {
    let files: TorrentFilesModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if files.isAllDownloaded {
                    summary
                } else {
                    Toggle(sources: wantedBindings, isOn: \.self) { summary }
                        .toggleStyle(.checkbox)
                        .help("Download all or none of the files")
                }

                Spacer(minLength: 8)

                if files.isOrdering || files.canOrder {
                    orderToggle
                }
            }
            if files.isOrdering {
                Label("Drag files to set the order. The top one downloads first.", systemImage: "list.number")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summary: some View {
        Text(files.summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }

    private var orderToggle: some View {
        Toggle("Download Files in Order", isOn: Binding(
            get: { files.isOrdering },
            set: { files.setOrdering($0) }
        ))
        .toggleStyle(.switch)
        .controlSize(.mini)
        .font(.caption)
        .foregroundStyle(.secondary)
        .help("Download the files one at a time, in the order you choose")
    }

    private var wantedBindings: [Binding<Bool>] {
        files.files.map { file in
            Binding(get: { file.isWanted }, set: { files.setWanted($0, for: [file]) })
        }
    }
}
