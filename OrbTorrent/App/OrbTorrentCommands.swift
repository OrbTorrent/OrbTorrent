import AppKit
import SwiftUI

/// Menu bar commands for the app menu.
struct OrbTorrentCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(AppIdentity.name)") {
                NSApp.activate()
                openWindow(id: "about")
            }
            if model.updates.isEnabled {
                Button("Check for Updates…") { model.updates.checkForUpdates() }
                    .disabled(!model.updates.canCheck)
            }
        }

        CommandGroup(replacing: .help) {
            Button("\(AppIdentity.name) Help") { NSWorkspace.shared.open(Website.docs) }
                .keyboardShortcut("?", modifiers: .command)
            Button("Troubleshooting") { NSWorkspace.shared.open(Website.troubleshooting) }
            Divider()
            Button("What's New in \(AppIdentity.name)") {
                model.updates.showWhatsNew()
                model.showMainWindow()
            }
            .disabled(model.updates.currentRelease == nil)
            Button("\(AppIdentity.name) Website") { NSWorkspace.shared.open(Website.home) }
            Divider()
            Button("Report a Problem…") {
                NSApp.activate()
                openWindow(id: "report")
            }
        }

        CommandGroup(replacing: .newItem) {
            Button("Open Torrent File…") { model.adder.presentOpenPanel() }
                .keyboardShortcut("o")
            Button("Add Magnet Link…") { model.adder.presentMagnetSheet() }
                .keyboardShortcut("u")
            Button("Add from Clipboard") {
                if let text = NSPasteboard.general.string(forType: .string) {
                    model.adder.add(text: text)
                }
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])
            Divider()
            Menu("Import From") {
                ForEach(ImportSource.allCases) { source in
                    Button("\(source.name)…") { model.showImport(from: source) }
                        .disabled(!source.hasLibrary)
                }
            }
            if model.extensions.isOn {
                Divider()
                Button("Install Extension…") { model.chooseExtensionToInstall() }
            }
            // OrbTorrent Dev only: the pages people see once, on demand.
            if AppIdentity.isDevelopment {
                Divider()
                Button("Show Welcome") {
                    model.isWelcomePresented = true
                    model.showMainWindow()
                }
                Button("Show What's New") {
                    model.updates.previewWhatsNew()
                    model.showMainWindow()
                }
            }
        }

        CommandMenu("Downloads") {
            Button("Pause All") { Task { await model.store.pauseAll() } }
                .keyboardShortcut(".", modifiers: [.command, .option])
            Button("Resume All") { Task { await model.store.resumeAll() } }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Divider()
            Button("Show in Finder") {
                model.store.selectedTorrents.forEach(FileActions.reveal)
            }
            .keyboardShortcut("r")
            .disabled(!showsSelection)
            Button("Remove…") { model.requestRemoval(of: model.store.selectedTorrents) }
                .keyboardShortcut(.delete)
                .disabled(!showsSelection)
            Divider()
            Button(model.isInspectorPresented ? "Hide Inspector" : "Show Inspector") {
                model.isInspectorPresented.toggle()
            }
            .keyboardShortcut("i")
        }
    }

    /// Selected downloads are only acted on while the library shows them.
    private var showsSelection: Bool {
        model.section == .library && !model.store.selection.isEmpty
    }
}
