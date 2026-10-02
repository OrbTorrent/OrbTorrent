import SwiftUI

/// Says a new version is ready to install, or available when one was found
/// while OrbTorrent was in the background, where Sparkle's window shows
/// what's new and installs it.
struct UpdateBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let name = model.updates.ready {
            banner(title: "\(AppIdentity.name) \(name) is ready",
                   detail: "Restart to install it. Your downloads carry on where they left off.",
                   action: "Restart to Update") {
                model.updates.installReadyUpdate(showingWindow: true)
            }
        } else if let name = model.updates.waiting {
            banner(title: "\(AppIdentity.name) \(name) is available",
                   detail: "See what's new, and install it when you're ready.",
                   action: "Update…") {
                model.updates.checkForUpdates()
            }
        }
    }

    private func banner(title: String, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Button(action, action: perform)
                .buttonStyle(.glassProminent)
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
