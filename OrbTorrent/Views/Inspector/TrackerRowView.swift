import SwiftUI

/// One tracker or peer source.
struct TrackerRowView: View {
    /// A fixed height keeps rows steady as their details come and go.
    static let height: CGFloat = 34

    let tracker: Tracker

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                Text(tracker.displayName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Text(tracker.status.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Self.height, maxHeight: Self.height, alignment: .leading)
        .help(tracker.message.isEmpty ? tracker.url : "\(tracker.url)\n\(tracker.message)")
    }

    /// The tracker's message when it has one, such as "timed out", otherwise
    /// what it has reported.
    private var detail: String? {
        if !tracker.message.isEmpty { return tracker.message }
        if tracker.status == .working || tracker.seeds + tracker.peers + tracker.leechers > 0 {
            return "\(tracker.seeds) seeds · \(tracker.leechers) leechers · \(tracker.peers) peers sent"
        }
        return nil
    }

    private var color: Color {
        switch tracker.status {
        case .working: .green
        case .updating, .notContacted: .orange
        case .disabled: .secondary
        case .notWorking, .trackerError, .unreachable: .red
        }
    }
}
