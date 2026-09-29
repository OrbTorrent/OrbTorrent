import SwiftUI

/// The Network settings for downloading only through a VPN.
struct VPNSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        Section {
            Toggle("Only download through a VPN", isOn: $settings.vpnOnly)
            if settings.vpnOnly {
                Picker("VPN", selection: $settings.vpnServiceID) {
                    Text("Any VPN").tag(String?.none)
                    ForEach(model.vpn.monitor.services) { service in
                        Text(service.name).tag(String?.some(service.id))
                    }
                }
                LabeledContent("Status") {
                    Label(statusTitle, systemImage: statusSymbol)
                        .labelStyle(.status(spacing: 6))
                        .foregroundStyle(statusColor)
                }
                if case .through = model.vpn.status {
                    LabeledContent {
                        Text(portTitle)
                            .foregroundStyle(.secondary)
                    } label: {
                        Text("Incoming connections")
                        if let portDetail {
                            Text(portDetail)
                        }
                    }
                }
                LabeledContent("Forwarded port") {
                    TextField("Forwarded port", value: $settings.vpnForwardedPort, format: .number.grouping(.never),
                              prompt: Text("Automatic"))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90)
                }
            }
        } header: {
            Text("VPN")
        } footer: {
            if settings.vpnOnly {
                Text("OrbTorrent uses only the VPN's connection. If the VPN drops, downloading and sharing stop instead of carrying on over your normal connection, and continue once it's back. “Any VPN” means one that carries all your internet traffic.\n\nA forwarded port lets other peers connect to you, which makes downloads faster. OrbTorrent gets it automatically from ProtonVPN, Private Internet Access, and other VPNs that forward ports over NAT-PMP. If your VPN has you reserve a port in your account instead, such as AirVPN or Windscribe, enter that port here.")
            } else {
                Text("OrbTorrent then uses only the VPN's connection, so nothing is downloaded or shared over your normal connection if the VPN drops.")
            }
        }
        .onChange(of: settings.vpnOnly) { Task { await model.vpn.apply() } }
        .onChange(of: settings.vpnServiceID) { Task { await model.vpn.apply() } }
        .onChange(of: settings.vpnForwardedPort) { Task { await model.vpn.ports.restart() } }
    }

    private var portTitle: String {
        switch model.vpn.ports.status {
        case .off, .searching: "Looking for a forwarded port…"
        case .forwarded(let port, _): "Port \(port.formatted(.number.grouping(.never)))"
        case .unavailable: "No port forwarded"
        }
    }

    /// What the port means, under the row's name.
    private var portDetail: String? {
        switch model.vpn.ports.status {
        case .off, .searching: nil
        case .forwarded(_, let source): "Forwarded by \(source), so peers can connect to you."
        case .unavailable:
            if case .through(let connection) = model.vpn.status {
                PortForwarder.noPortExplanation(forVPNNamed: connection.name)
            } else {
                nil
            }
        }
    }

    private var statusTitle: String {
        switch model.vpn.status {
        case .off: ""
        case .through(let connection): "Connected through \(connection.name)"
        case .waitingForVPN: "Not connected, so nothing is downloading"
        }
    }

    private var statusSymbol: String {
        switch model.vpn.status {
        case .through: "lock.shield.fill"
        case .off, .waitingForVPN: "exclamationmark.shield.fill"
        }
    }

    private var statusColor: Color {
        switch model.vpn.status {
        case .through: .green
        case .off, .waitingForVPN: .orange
        }
    }
}
