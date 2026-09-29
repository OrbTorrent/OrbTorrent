import SwiftUI

struct SpeedSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var downloadLimited = false
    @State private var downloadLimit = 10_000
    @State private var uploadLimited = true
    @State private var uploadLimit = 5_000
    @State private var hasLoaded = false

    var body: some View {
        Form {
            Section {
                Toggle("Limit download speed", isOn: $downloadLimited)
                if downloadLimited {
                    limitField("Maximum download speed", value: $downloadLimit)
                }
            }
            Section {
                Toggle("Limit upload speed", isOn: $uploadLimited)
                if uploadLimited {
                    limitField("Maximum upload speed", value: $uploadLimit)
                }
            } footer: {
                Text("Keeping uploads below your connection's maximum stops them from slowing down your downloads and other internet use.")
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onChange(of: model.preferences) { _, _ in if !hasLoaded { load() } }
        .task(id: "\(downloadLimited)|\(downloadLimit)|\(uploadLimited)|\(uploadLimit)") {
            guard hasLoaded else { return }
            // Waits for typing to pause; a newer change starts the wait over.
            guard (try? await Task.sleep(for: .milliseconds(600))) != nil else { return }
            save()
        }
        .onDisappear(perform: save)
    }

    /// Sends the limits to the engine, on its own so that closing Settings
    /// doesn't cut it off.
    private func save() {
        guard hasLoaded else { return }
        let values: [String: PreferenceValue] = [
            "dl_limit": .int(downloadLimited ? Int64(max(downloadLimit, 1)) * 1_024 : 0),
            "up_limit": .int(uploadLimited ? Int64(max(uploadLimit, 1)) * 1_024 : 0),
        ]
        Task { await model.updatePreferences(values) }
    }

    private func limitField(_ title: String, value: Binding<Int>) -> some View {
        LabeledContent(title) {
            HStack(spacing: 6) {
                TextField(title, value: value, format: .number)
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 90)
                Text("KB/s")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func load() {
        guard let preferences = model.preferences else { return }
        downloadLimited = preferences.downloadLimit > 0
        if preferences.downloadLimit > 0 { downloadLimit = Int(preferences.downloadLimit / 1_024) }
        uploadLimited = preferences.uploadLimit > 0
        if preferences.uploadLimit > 0 { uploadLimit = Int(preferences.uploadLimit / 1_024) }
        hasLoaded = true
    }
}
