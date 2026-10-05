import SwiftUI

/// Asks, in the menu bar panel, before a download is deleted with its files,
/// which go to the Trash or are erased as the settings say.
///
/// The panel closes as soon as it loses focus, so it can't show an alert; this
/// takes the place of the controls that asked for it instead.
struct MenuBarDeleteConfirmation: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    let onCancel: () -> Void
    let onDelete: () async -> Void
    @State private var isDeleting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Delete “\(model.store.shownName(torrent.name))”?")
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Button("Cancel", action: onCancel)
                Button("Delete", role: .destructive) {
                    isDeleting = true
                    Task { await onDelete() }
                }
            }
            .buttonStyle(.glassCapsule)
            .disabled(isDeleting)
        }
    }

    private var message: String {
        let onDisk = torrent.downloadedSize
        switch model.settings.deleteBehavior {
        case .moveToTrash:
            return onDisk > 0 ? "Its \(Format.bytes(onDisk)) of files go to the Trash." : "Anything it downloaded goes to the Trash."
        case .deletePermanently:
            let what = onDisk > 0 ? "Its \(Format.bytes(onDisk)) of files are" : "Anything it downloaded is"
            return "\(what) erased from your Mac, not moved to the Trash."
        }
    }
}
