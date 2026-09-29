import SwiftUI

/// Suggests making OrbTorrent the default app for magnet links and torrent files.
struct DefaultAppBanner: View {
    @Environment(AppModel.self) private var model
    @State private var isWorking = false

    var body: some View {
        // OrbTorrent Dev leaves opening links and files to OrbTorrent.
        if !AppIdentity.isDevelopment,
           model.settings.hasCompletedOnboarding,
           !model.settings.dismissedDefaultAppBanner,
           !model.defaultApp.isDefault {
            HStack(spacing: 12) {
                Image(systemName: "link.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Open torrents with OrbTorrent")
                        .font(.callout.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button("Not Now") {
                    model.settings.dismissedDefaultAppBanner = true
                }
                .buttonStyle(.glass)
                Button("Make Default") {
                    isWorking = true
                    Task {
                        try? await model.defaultApp.makeDefault()
                        isWorking = false
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isWorking)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .frame(maxWidth: 640)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var subtitle: String {
        if let current = model.defaultApp.currentMagnetHandlerName {
            return "Magnet links currently open in \(current)."
        }
        return "Magnet links and .torrent files will open here."
    }
}
