import SwiftUI

struct NetworkSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var port = 0
    @State private var portMapping = true
    @State private var peerProtocol: EnginePreferences.PeerProtocol = .both
    @State private var dht = true
    @State private var pex = true
    @State private var lsd = true
    @State private var encryption: EnginePreferences.Encryption = .prefer
    @State private var maxConnections = 500
    @State private var maxConnectionsPerTorrent = 100
    @State private var hasLoaded = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            VPNSettingsSection()

            Section {
                LabeledContent("Status") {
                    Label(statusTitle, systemImage: statusSymbol)
                        .labelStyle(.status(spacing: 6))
                        .foregroundStyle(statusColor)
                }
                LabeledContent("Listening port") {
                    HStack(spacing: 8) {
                        TextField("Port", value: $port, format: .number.grouping(.never))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Button("Random") { port = Int.random(in: 20_000...60_000) }
                    }
                }
                .disabled(forwarding != nil)
                Toggle("Open the port on my router automatically (UPnP / NAT-PMP)", isOn: $portMapping)
                    .disabled(forwarding != nil)
            } header: {
                Text("Connection")
            } footer: {
                if let forwarding {
                    Text("While downloading through the VPN, OrbTorrent listens on port \(forwarding.port, format: .number.grouping(.never)), which \(forwarding.source) forwards. Your own port and router setting come back when you stop using the VPN.")
                } else {
                    Text("If incoming connections stay blocked, your internet provider may use carrier-grade NAT. Ask them for a public IP address, or use a VPN that supports port forwarding.")
                }
            }

            Section("Peers") {
                Picker("Connect using", selection: $peerProtocol) {
                    ForEach(EnginePreferences.PeerProtocol.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Find peers through DHT", isOn: $dht)
                Toggle("Exchange peers with other peers (PeX)", isOn: $pex)
                Toggle("Find peers on the local network", isOn: $lsd)
                Picker("Encryption", selection: $encryption) {
                    ForEach(EnginePreferences.Encryption.allCases) { Text($0.title).tag($0) }
                }
            }

            Section {
                Toggle("Find more peers for public torrents", isOn: $settings.findMorePeers)
            } footer: {
                Text("Adds trackers from a public list that's tested every day, so slow downloads find more people to download from. Torrents from private trackers are never changed.\n\(trackerListStatus)")
            }
            .onChange(of: settings.findMorePeers) { _, isOn in
                if isOn { Task { await model.trackerList.updateIfNeeded() } }
            }

            Section("Limits") {
                LabeledContent("Maximum connections") {
                    TextField("Maximum connections", value: $maxConnections, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                LabeledContent("Per download") {
                    TextField("Per download", value: $maxConnectionsPerTorrent, format: .number)
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onChange(of: model.preferences) { _, _ in if !hasLoaded { load() } }
        .task(id: fingerprint) {
            guard hasLoaded else { return }
            // Waits for typing to pause; a newer change starts the wait over.
            guard (try? await Task.sleep(for: .milliseconds(700))) != nil else { return }
            save()
        }
        .onDisappear(perform: save)
    }

    /// Sends the settings to the engine, on its own so that closing Settings
    /// doesn't cut it off.
    private func save() {
        guard hasLoaded else { return }
        var values: [String: PreferenceValue] = [
            "bittorrent_protocol": .int(Int64(peerProtocol.rawValue)),
            "dht": .bool(dht),
            "pex": .bool(pex),
            "lsd": .bool(lsd),
            "encryption": .int(Int64(encryption.rawValue)),
            "max_connec": .int(Int64(max(maxConnections, 10))),
            "max_connec_per_torrent": .int(Int64(max(maxConnectionsPerTorrent, 5))),
        ]
        // A forwarded port sets these aside; they're put back afterwards.
        if forwarding == nil {
            values["listen_port"] = .int(Int64(min(max(port, 1_024), 65_535)))
            values["upnp"] = .bool(portMapping)
        }
        Task { await model.updatePreferences(values) }
    }

    private var trackerListStatus: String {
        let list = model.trackerList
        let count = Format.count(list.trackers.count, "tracker")
        guard let updated = list.updated else { return "\(count), from the list OrbTorrent came with." }
        return "\(count), from the list updated \(updated.formatted(.relative(presentation: .named)))."
    }

    /// The port the engine listens on and who forwards it, while one does.
    private var forwarding: (port: Int, source: String)? {
        if case .forwarded(let port, let source) = model.vpn.ports.status { return (port, source) }
        return nil
    }

    private var fingerprint: String {
        [port, portMapping ? 1 : 0, peerProtocol.rawValue, dht ? 1 : 0, pex ? 1 : 0, lsd ? 1 : 0,
         encryption.rawValue, maxConnections, maxConnectionsPerTorrent].map(String.init).joined(separator: "|")
    }

    private func load() {
        guard let preferences = model.preferences else { return }
        // Your own port and mapping, even while a VPN's forwarded port is in use.
        let own = model.vpn.ports.setAside
        port = own?.port ?? preferences.listenPort
        portMapping = own?.portMapping ?? preferences.portMapping
        peerProtocol = preferences.peerProtocol
        dht = preferences.dht
        pex = preferences.pex
        lsd = preferences.lsd
        encryption = preferences.encryption
        maxConnections = preferences.maxConnections
        maxConnectionsPerTorrent = preferences.maxConnectionsPerTorrent
        hasLoaded = true
    }

    private var statusTitle: String {
        switch model.store.transfer.connectionStatus {
        case .connected: "Reachable by peers"
        case .firewalled: "Incoming connections blocked"
        case .disconnected: "Offline"
        }
    }

    private var statusSymbol: String {
        switch model.store.transfer.connectionStatus {
        case .connected: "checkmark.circle.fill"
        case .firewalled: "exclamationmark.shield.fill"
        case .disconnected: "wifi.slash"
        }
    }

    private var statusColor: Color {
        switch model.store.transfer.connectionStatus {
        case .connected: .green
        case .firewalled: .orange
        case .disconnected: .secondary
        }
    }
}
