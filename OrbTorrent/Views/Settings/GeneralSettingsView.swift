import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var loginItemError: String?

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            if AppIdentity.isDevelopment {
                Section {
                    Text(AppIdentity.developmentNote)
                        .foregroundStyle(.secondary)
                }
            } else {
                appSection
            }

            Section("Adding Torrents") {
                Picker(selection: $settings.addBehavior) {
                    ForEach(AppSettings.AddBehavior.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("When you open a torrent")
                    if settings.addBehavior == .askFirst {
                        Text("Links from your browser and files from Finder are asked about in the menu bar, where you can pick the files and folder.")
                    }
                }
                Toggle("Show the OrbTorrent window when a download is added", isOn: $settings.openWindowOnAdd)
                Toggle("Keep the Mac awake while downloading", isOn: $settings.preventSleepWhileDownloading)
            }

            Section("Deleting Downloads") {
                Picker(selection: $settings.deleteBehavior) {
                    ForEach(AppSettings.DeleteBehavior.allCases) { Text($0.title).tag($0) }
                } label: {
                    Text("When you delete a download")
                    switch settings.deleteBehavior {
                    case .moveToTrash:
                        Text("You can put files back from the Trash. They still take up space until you empty it.")
                    case .deletePermanently:
                        Text("Files are erased from your Mac right away and can't be put back.")
                    }
                }
            }

            Section("Appearance") {
                Toggle("Show OrbTorrent in the Dock while its window is open", isOn: $settings.showDockIcon)
            }

            Section("Notifications") {
                Toggle("Notify me when a download finishes", isOn: $settings.notifyOnCompletion)
                    .onChange(of: settings.notifyOnCompletion) { _, enabled in
                        if enabled { model.notifier.requestAuthorization() }
                    }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            model.defaultApp.refresh()
            model.loginItem.refresh()
        }
        .alert("Couldn't Change Login Item", isPresented: Binding(
            get: { loginItemError != nil },
            set: { if !$0 { loginItemError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(loginItemError ?? "")
        }
    }

    /// The default app for torrents, and starting at login.
    private var appSection: some View {
        Section {
            LabeledContent("Default torrent app") {
                if model.defaultApp.isDefault {
                    Label("OrbTorrent", systemImage: "checkmark.circle.fill")
                        .labelStyle(.status(spacing: 6))
                        .foregroundStyle(.green)
                } else {
                    Button("Make OrbTorrent the Default") {
                        Task { try? await model.defaultApp.makeDefault() }
                    }
                }
            }
            Toggle("Open OrbTorrent when you log in", isOn: Binding(
                get: { model.loginItem.isEnabled },
                set: { enabled in
                    do {
                        try model.loginItem.setEnabled(enabled)
                    } catch {
                        loginItemError = error.localizedDescription
                    }
                }
            ))
            if model.loginItem.needsApproval {
                Button("Allow in Login Items Settings…") { model.loginItem.openSystemSettings() }
            }
        }
    }
}
