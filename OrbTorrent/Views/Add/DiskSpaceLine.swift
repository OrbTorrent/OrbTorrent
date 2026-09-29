import SwiftUI

/// The free space on the disk a new download goes to, or a warning when it
/// won't fit there. Shown under the folder in both add confirmations.
struct DiskSpaceLine: View {
    @Environment(AppModel.self) private var model
    let pending: AddTorrentCoordinator.Pending
    /// Its icon ends at the confirmation's icon column, and its text starts
    /// with the rows above.
    var iconColumn: CGFloat = 16
    var iconWidth: CGFloat = 16
    var gap: CGFloat = 6
    @State private var room: DiskSpace.Room?

    var body: some View {
        let folder = model.adder.saveFolder(for: pending)
        // A stack rather than a group: an empty group never runs the task.
        VStack(alignment: .leading, spacing: 0) {
            if let room {
                if let needed = pending.neededBytes, !room.fits(needed) {
                    warning(room, needed: needed)
                } else {
                    line(icon: Image(systemName: "internaldrive").foregroundStyle(.secondary)) {
                        Text("\(Format.bytes(room.available)) free on “\(room.disk)”")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        // Looking up free space takes a moment, so only when the folder changes.
        .task(id: folder) {
            let downloads = model.store.unfinishedDownloads
            room = await Task.detached { DiskSpace.room(forFolder: folder, downloads: downloads) }.value
        }
    }

    private func warning(_ room: DiskSpace.Room, needed: Int64) -> some View {
        line(icon: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Not enough space")
                    .fontWeight(.semibold)
                Text(detail(room, needed: needed))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func line<Icon: View, Content: View>(icon: Icon, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: gap) {
            icon
                .frame(width: iconWidth, alignment: .leading)
                .frame(width: iconColumn, alignment: .trailing)
            content()
        }
    }

    private func detail(_ room: DiskSpace.Room, needed: Int64) -> String {
        var text = "Needs \(Format.bytes(needed)), and “\(room.disk)” has \(Format.bytes(room.available)) free"
        if room.othersNeed > 0 {
            text += ", with \(Format.bytes(room.othersNeed)) still to come for your other downloads"
        }
        text += ". "
        text += model.settings.pauseWhenDiskFull
            ? "It would pause before finishing, to keep \(Format.bytes(DiskSpace.reserve)) free for your Mac."
            : "It would run out of space before finishing."
        return text
    }
}
