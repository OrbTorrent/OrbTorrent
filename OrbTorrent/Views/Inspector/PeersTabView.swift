import SwiftUI

/// The peers currently connected for a download.
struct PeersTabView: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    @State private var peers: [Peer] = []
    @State private var hasLoaded = false

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            Divider()
            if !hasLoaded {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if peers.isEmpty {
                ContentUnavailableView(
                    "No Peers Connected",
                    systemImage: "person.2.slash",
                    description: Text(torrent.state.isStopped
                        ? "Resume the download to connect to peers."
                        : "OrbTorrent is looking for peers. This can take a moment.").font(.callout)
                )
                .frame(maxHeight: .infinity)
            } else {
                List(peers) { peer in
                    PeerRowView(peer: peer)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, PeerRowView.height + 8)
            }
        }
        .task(id: torrent.hash) {
            while !Task.isCancelled {
                if let latest = try? await model.store.peers(of: torrent.hash) {
                    peers = latest
                }
                hasLoaded = true
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Label(Format.count(peers.count, "peer"), systemImage: "person.2")
            Label("\(peers.filter(\.isSeed).count) seeding", systemImage: "arrow.up.circle")
            Label("\(peers.filter(\.isUTP).count) µTP", systemImage: "bolt.horizontal")
            Label("\(peers.filter(\.isIncoming).count) incoming", systemImage: "arrow.down.left")
                .help("Peers that connected to you. Behind a closed port these arrive through µTP hole punching.")
            Spacer(minLength: 0)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }
}
