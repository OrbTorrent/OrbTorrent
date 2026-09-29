import SwiftUI

/// One connected peer.
struct PeerRowView: View {
    /// Peers come and go every few seconds; a fixed height keeps inserted rows
    /// from being mis-measured by the list.
    static let height: CGFloat = 36

    let peer: Peer

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(peer.ip)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                if peer.isIncoming {
                    tag("Incoming", .green)
                }
                tag(peer.isUTP ? "µTP" : "TCP", .secondary)
                if peer.isEncrypted {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help("Encrypted connection")
                }
                Spacer(minLength: 0)
                Text(Format.percent(peer.progress))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(peer.isSeed ? .green : .secondary)
            }
            HStack(spacing: 10) {
                Text(peer.client.isEmpty ? "Unknown client" : peer.client)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if peer.downloadSpeed > 0 {
                    Text("↓ \(Format.speed(peer.downloadSpeed))")
                }
                if peer.uploadSpeed > 0 {
                    Text("↑ \(Format.speed(peer.uploadSpeed))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .frame(height: Self.height)
        .help(peer.flagsDescription)
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(color.opacity(0.14), in: .capsule)
    }
}
