import SwiftUI

/// Says downloads are going through a VPN, when the settings ask for one.
struct VPNBadge: View {
    let name: String
    /// The gap after the shield, the same as the dot's in the problem line it replaces.
    var spacing: CGFloat = 5

    var body: some View {
        Label {
            Text("Through \(name)")
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(.green)
        }
        .labelStyle(.status(spacing: spacing))
        .font(.caption)
        .help("Downloads only use \(name)'s connection. If it drops, they stop until it's back.")
    }
}
