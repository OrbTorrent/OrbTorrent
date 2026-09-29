import SwiftUI

/// OrbTorrent's Settings window.
struct SettingsView: View {
    enum Tab: String {
        case general, downloads, speed, network, engine, about
    }

    static let tabKey = "settingsTab"
    @AppStorage(SettingsView.tabKey) private var tab = Tab.general

    var body: some View {
        TabView(selection: $tab) {
            SwiftUI.Tab("General", systemImage: "gearshape", value: .general) { GeneralSettingsView().frame(width: 560) }
            SwiftUI.Tab("Downloads", systemImage: "arrow.down.circle", value: .downloads) { DownloadsSettingsView().frame(width: 560) }
            SwiftUI.Tab("Speed", systemImage: "speedometer", value: .speed) { SpeedSettingsView().frame(width: 560) }
            SwiftUI.Tab("Network", systemImage: "network", value: .network) { NetworkSettingsView().frame(width: 560) }
            SwiftUI.Tab("Engine", systemImage: "shippingbox", value: .engine) { EngineSettingsView().frame(width: 560) }
            SwiftUI.Tab("About", systemImage: "info.circle", value: Tab.about) { AboutSettingsView().frame(width: 560) }
        }
        .frame(minHeight: 420)
    }
}
