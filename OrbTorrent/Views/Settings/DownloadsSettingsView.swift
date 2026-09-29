import AppKit
import SwiftUI

struct DownloadsSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var ratioLimited = false
    @State private var ratio = 2.0
    @State private var ratioAction: EnginePreferences.RatioAction = .stop
    @State private var hasLoaded = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                LabeledContent("Save downloads to") {
                    HStack(spacing: 8) {
                        Text(displayPath(model.preferences?.savePath))
                            .lineLimit(1)
                            .truncationMode(.head)
                            .foregroundStyle(.secondary)
                        Button("Change…", action: chooseFolder)
                    }
                }
            } footer: {
                Text("New downloads go here unless you choose another folder when adding them.")
            }

            Section {
                Toggle("Pause downloads when the disk is almost full", isOn: $settings.pauseWhenDiskFull)
            } header: {
                Text("Disk Space")
            } footer: {
                Text("Keeps \(Format.bytes(DiskSpace.reserve)) free for your Mac. Paused downloads resume by themselves once the disk has \(Format.bytes(DiskSpace.resumeAt)) free.")
            }

            Section("Seeding") {
                Toggle("Stop sharing when the ratio reaches a limit", isOn: $ratioLimited)
                if ratioLimited {
                    LabeledContent("Ratio limit") {
                        TextField("Ratio", value: $ratio, format: .number.precision(.fractionLength(0...2)))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                    Picker("Then", selection: $ratioAction) {
                        ForEach([EnginePreferences.RatioAction.stop, .remove]) { Text($0.title).tag($0) }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onChange(of: model.preferences) { _, _ in if !hasLoaded { load() } }
        .task(id: "\(ratioLimited)|\(ratio)|\(ratioAction.rawValue)") {
            guard hasLoaded else { return }
            // Waits for typing to pause; a newer change starts the wait over.
            guard (try? await Task.sleep(for: .milliseconds(500))) != nil else { return }
            save()
        }
        .onDisappear(perform: save)
    }

    /// Sends the sharing limits to the engine, on its own so that closing
    /// Settings doesn't cut it off.
    private func save() {
        guard hasLoaded else { return }
        let values: [String: PreferenceValue] = [
            "max_ratio_enabled": .bool(ratioLimited),
            "max_ratio": .double(max(ratio, 0)),
            "max_ratio_act": .int(Int64(ratioAction.rawValue)),
        ]
        Task { await model.updatePreferences(values) }
    }

    private func load() {
        guard let preferences = model.preferences else { return }
        ratioLimited = preferences.ratioLimitEnabled
        ratio = preferences.ratioLimit
        ratioAction = preferences.ratioAction
        hasLoaded = true
    }

    private func displayPath(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "—" }
        return (path as NSString).abbreviatingWithTildeInPath
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        if let current = model.preferences?.savePath {
            panel.directoryURL = URL(fileURLWithPath: current)
        }
        if panel.runModal() == .OK, let url = panel.url {
            Task { await model.updatePreferences(["save_path": .string(url.path)]) }
        }
    }
}
