import AppKit
import SwiftUI

struct EngineSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var importing: ImportSource?

    var body: some View {
        Form {
            Section {
                LabeledContent("Status") {
                    Label(statusText, systemImage: statusSymbol)
                        .labelStyle(.status(spacing: 6))
                        .foregroundStyle(statusColor)
                }
                LabeledContent("qBittorrent", value: model.engine.version ?? "—")
                if let info = model.engine.buildInfo {
                    LabeledContent("libtorrent", value: info.libtorrent)
                    LabeledContent("Qt", value: info.qt)
                    LabeledContent("OpenSSL", value: info.openssl)
                    LabeledContent("Boost", value: info.boost)
                }
            } header: {
                Text("Download Engine")
            } footer: {
                Text("OrbTorrent downloads with a private copy of qBittorrent that runs in the background and only accepts connections from this Mac.")
            }

            Section {
                Button("Restart Engine") { Task { await model.restartEngine() } }
                Button("Show Engine Log") { NSWorkspace.shared.open(EnginePaths.engineLog) }
                Button("Show Data Folder in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([EnginePaths.profile])
                }
            }

            Section {
                ForEach(ImportSource.allCases) { source in
                    LabeledContent(source.name) {
                        if source.hasLibrary {
                            Button("Import…") { importing = source }
                        } else {
                            Text("Not on this Mac")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Brings over another app's downloads and settings. You choose what comes over before anything changes.")
            }
        }
        .formStyle(.grouped)
        .sheet(item: $importing) { source in
            ImportSheet(source: source)
        }
    }

    private var statusText: String {
        switch model.engine.status {
        case .running: "Running"
        case .starting: "Starting…"
        case .stopped: "Stopped"
        case .failed: "Not running"
        }
    }

    private var statusSymbol: String {
        model.engine.isRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    private var statusColor: Color {
        model.engine.isRunning ? .green : .orange
    }
}
