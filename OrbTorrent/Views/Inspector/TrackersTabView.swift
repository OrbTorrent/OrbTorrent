import SwiftUI

/// Trackers and peer-discovery sources for a download.
struct TrackersTabView: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    @State private var trackers: [Tracker] = []
    @State private var hasLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(working) of \(realTrackers.count) trackers working")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Ask for More Peers", systemImage: "antenna.radiowaves.left.and.right") {
                    Task { await model.store.reannounce([torrent.hash]) }
                }
                .controlSize(.small)
                .buttonStyle(.glass)
                .disabled(torrent.state.isStopped)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider()

            if !hasLoaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Laid out by hand rather than as a sectioned list, whose pinned
                // headers and section separators don't line up with the rows.
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if !realTrackers.isEmpty {
                            group("Trackers", realTrackers)
                        }
                        let sources = trackers.filter(\.isPeerSource)
                        if !sources.isEmpty {
                            group("Peer Discovery", sources)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .task(id: torrent.hash) {
            while !Task.isCancelled {
                if let latest = try? await model.store.trackers(of: torrent.hash) {
                    trackers = latest
                }
                hasLoaded = true
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    /// A heading, then the rows with a line between each.
    private func group(_ title: String, _ items: [Tracker]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.bottom, 4)
            ForEach(items) { tracker in
                TrackerRowView(tracker: tracker)
                    .padding(.vertical, 6)
                if tracker.id != items.last?.id {
                    Divider()
                }
            }
        }
    }

    private var realTrackers: [Tracker] { trackers.filter { !$0.isPeerSource } }
    private var working: Int { realTrackers.filter { $0.status == .working }.count }
}
