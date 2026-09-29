import SwiftUI

/// Says a new version is ready, when one was found while OrbTorrent was in
/// the background. Sparkle's window shows what's new and installs it.
struct UpdateBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let name = model.updates.waiting {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(AppIdentity.name) \(name) is available")
                        .font(.callout.weight(.semibold))
                    Text("See what's new, and install it when you're ready.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button("Update…") {
                    model.updates.checkForUpdates()
                }
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
}
