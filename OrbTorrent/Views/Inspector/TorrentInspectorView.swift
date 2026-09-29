import SwiftUI

/// Files, details, peers and trackers for one download.
struct TorrentInspectorView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case files = "Files"
        case details = "Details"
        case peers = "Peers"
        case trackers = "Trackers"
        case checks = "Checks"
        var id: String { rawValue }
    }

    @Environment(AppModel.self) private var model
    let torrent: Torrent
    @AppStorage("inspectorTab") private var tab: Tab = .files

    /// Checks only while extensions are on.
    private var tabs: [Tab] {
        Tab.allCases.filter { $0 != .checks || model.extensions.isOn }
    }

    /// The tab chosen, or Files if it's gone.
    private var shownTab: Binding<Tab> {
        Binding(get: { tabs.contains(tab) ? tab : .files }, set: { tab = $0 })
    }

    var body: some View {
        VStack(spacing: 0) {
            InspectorHeader(torrent: torrent)
                .padding(16)

            FullWidthSegmentedControl(options: tabs.map { ($0.rawValue, $0) }, selection: shownTab)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider()

            Group {
                switch shownTab.wrappedValue {
                case .files: FilesTabView(torrent: torrent, store: model.store)
                case .details: DetailsTabView(torrent: torrent)
                case .peers: PeersTabView(torrent: torrent)
                case .trackers: TrackersTabView(torrent: torrent)
                case .checks: ChecksTabView(torrent: torrent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}
