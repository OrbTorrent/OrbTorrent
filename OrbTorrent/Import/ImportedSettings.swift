import Foundation

/// Settings another app used, in OrbTorrent's terms. A setting is nil when
/// the app doesn't record a choice for it, so OrbTorrent keeps its own.
struct ImportedSettings: Sendable, Equatable {
    /// Bytes per second, or 0 for no limit.
    var downloadLimit: Int64?
    var uploadLimit: Int64?
    var savePath: String?
    /// Negative for no limit.
    var ratioLimit: Double?
    var ratioAction: EnginePreferences.RatioAction?
    var listenPort: Int?
    var portMapping: Bool?
    var peerProtocol: EnginePreferences.PeerProtocol?
    var dht: Bool?
    var pex: Bool?
    var lsd: Bool?
    var encryption: EnginePreferences.Encryption?
    var maxConnections: Int?
    var maxConnectionsPerTorrent: Int?

    /// The settings that differ from OrbTorrent's, each ready to apply.
    func changes(from current: EnginePreferences) -> [ImportedSetting] {
        var changes: [ImportedSetting] = []
        func add(_ kind: ImportedSetting.Kind, _ title: String, _ value: String, _ preferences: [String: PreferenceValue]) {
            changes.append(ImportedSetting(kind: kind, title: title, value: value, preferences: preferences))
        }

        if let savePath, FileManager.default.fileExists(atPath: savePath),
           URL(filePath: savePath).standardizedFileURL != URL(filePath: current.savePath).standardizedFileURL {
            add(.savePath, "Save downloads to", (savePath as NSString).abbreviatingWithTildeInPath,
                ["save_path": .string(savePath)])
        }
        if let downloadLimit, downloadLimit >= 0, downloadLimit != current.downloadLimit {
            add(.downloadLimit, "Download speed", Self.speed(downloadLimit), ["dl_limit": .int(downloadLimit)])
        }
        if let uploadLimit, uploadLimit >= 0, uploadLimit != current.uploadLimit {
            add(.uploadLimit, "Upload speed", Self.speed(uploadLimit), ["up_limit": .int(uploadLimit)])
        }
        if let ratioLimit {
            let isLimited = ratioLimit >= 0
            let action = ratioAction ?? current.ratioAction
            if isLimited {
                if !current.ratioLimitEnabled || ratioLimit != current.ratioLimit || action != current.ratioAction {
                    add(.ratio, "Ratio limit", "\(ratioLimit.formatted(.number.precision(.fractionLength(0...2)))), then \(action.title)",
                        ["max_ratio_enabled": .bool(true), "max_ratio": .double(ratioLimit), "max_ratio_act": .int(Int64(action.rawValue))])
                }
            } else if current.ratioLimitEnabled {
                add(.ratio, "Ratio limit", "None", ["max_ratio_enabled": .bool(false)])
            }
        }
        if let listenPort, (1_024...65_535).contains(listenPort), listenPort != current.listenPort {
            add(.listenPort, "Listening port", String(listenPort), ["listen_port": .int(Int64(listenPort))])
        }
        if let portMapping, portMapping != current.portMapping {
            add(.portMapping, "Open the port on the router automatically", Self.onOff(portMapping), ["upnp": .bool(portMapping)])
        }
        if let peerProtocol, peerProtocol != current.peerProtocol {
            add(.peerProtocol, "Connect using", peerProtocol.title, ["bittorrent_protocol": .int(Int64(peerProtocol.rawValue))])
        }
        if let dht, dht != current.dht {
            add(.dht, "Find peers through DHT", Self.onOff(dht), ["dht": .bool(dht)])
        }
        if let pex, pex != current.pex {
            add(.pex, "Exchange peers with other peers (PeX)", Self.onOff(pex), ["pex": .bool(pex)])
        }
        if let lsd, lsd != current.lsd {
            add(.lsd, "Find peers on the local network", Self.onOff(lsd), ["lsd": .bool(lsd)])
        }
        if let encryption, encryption != current.encryption {
            add(.encryption, "Encryption", encryption.title, ["encryption": .int(Int64(encryption.rawValue))])
        }
        // OrbTorrent's own settings keep at least these many.
        if let maxConnections, maxConnections > 0, max(maxConnections, 10) != current.maxConnections {
            let value = max(maxConnections, 10)
            add(.maxConnections, "Maximum connections", value.formatted(), ["max_connec": .int(Int64(value))])
        }
        if let maxConnectionsPerTorrent, maxConnectionsPerTorrent > 0,
           max(maxConnectionsPerTorrent, 5) != current.maxConnectionsPerTorrent {
            let value = max(maxConnectionsPerTorrent, 5)
            add(.maxConnectionsPerTorrent, "Connections per download", value.formatted(),
                ["max_connec_per_torrent": .int(Int64(value))])
        }
        return changes
    }

    private static func speed(_ bytesPerSecond: Int64) -> String {
        bytesPerSecond == 0 ? "Unlimited" : "\((bytesPerSecond / 1_024).formatted()) KB/s"
    }

    private static func onOff(_ isOn: Bool) -> String { isOn ? "On" : "Off" }
}

/// One setting to bring over, as the engine takes it.
struct ImportedSetting: Identifiable, Sendable {
    enum Kind: Sendable {
        case savePath, downloadLimit, uploadLimit, ratio, listenPort, portMapping
        case peerProtocol, dht, pex, lsd, encryption, maxConnections, maxConnectionsPerTorrent
    }

    let kind: Kind
    let title: String
    let value: String
    let preferences: [String: PreferenceValue]

    var id: Kind { kind }

    /// Whether it's about the listening port, which a VPN's forwarded port
    /// takes the place of while it's in use.
    var isAboutPort: Bool { kind == .listenPort || kind == .portMapping }
}
