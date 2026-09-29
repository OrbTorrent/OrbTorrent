import AppKit
import SwiftUI

/// Actions available for one or more selected downloads.
struct TorrentContextMenu: View {
    @Environment(AppModel.self) private var model
    let torrents: [Torrent]

    private var single: Torrent? { torrents.count == 1 ? torrents.first : nil }
    private var anyRunning: Bool { torrents.contains { !$0.state.isStopped } }

    var body: some View {
        if let single {
            Button("Open", systemImage: "arrow.up.forward.app") { FileActions.open(single) }
            Button("Show in Finder", systemImage: "folder") { FileActions.reveal(single) }
            Divider()
        }

        Button(anyRunning ? "Pause" : "Resume", systemImage: anyRunning ? "pause" : "play") {
            Task { await model.store.togglePause(torrents) }
        }

        if let single {
            Button(single.sequentialDownload ? "Turn Off Sequential Download" : "Download Sequentially",
                   systemImage: "list.number") {
                Task { await model.store.toggleSequentialDownload(single) }
            }
            Button("Copy Magnet Link", systemImage: "link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(single.magnetURI, forType: .string)
            }
        }

        Menu("More", systemImage: "ellipsis.circle") {
            Button("Ask Trackers for More Peers", systemImage: "antenna.radiowaves.left.and.right") {
                Task { await model.store.reannounce(torrents.map(\.hash)) }
            }
            Button("Verify Local Data", systemImage: "checkmark.shield") {
                Task { await model.store.recheck(torrents.map(\.hash)) }
            }
            Button("Move To…", systemImage: "folder.badge.gearshape") {
                chooseDestination()
            }
        }

        Divider()

        Button("Remove…", systemImage: "trash", role: .destructive) {
            model.requestRemoval(of: torrents)
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Move Downloads"
        panel.prompt = "Move Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.store.move(torrents, to: url) }
        }
    }
}
