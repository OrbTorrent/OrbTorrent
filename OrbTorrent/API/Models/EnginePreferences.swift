import Foundation

/// The subset of qBittorrent's preferences that OrbTorrent exposes in Settings,
/// from `GET /api/v2/app/preferences`. Speed limits are in bytes per second;
/// zero means unlimited.
struct EnginePreferences: Sendable, Decodable, Equatable {
    enum Encryption: Int, CaseIterable, Identifiable, Sendable, Decodable {
        case prefer = 0, require = 1, disable = 2
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .prefer: "Prefer Encryption"
            case .require: "Require Encryption"
            case .disable: "Disable Encryption"
            }
        }
    }

    enum PeerProtocol: Int, CaseIterable, Identifiable, Sendable, Decodable {
        case both = 0, tcp = 1, utp = 2
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .both: "TCP and µTP"
            case .tcp: "TCP Only"
            case .utp: "µTP Only"
            }
        }
    }

    enum RatioAction: Int, CaseIterable, Identifiable, Sendable, Decodable {
        case stop = 0, remove = 1, removeWithFiles = 3, superSeed = 2
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .stop: "Stop Seeding"
            case .remove: "Remove Torrent"
            case .removeWithFiles: "Remove Torrent and Files"
            case .superSeed: "Enable Super Seeding"
            }
        }
    }

    var savePath: String
    var downloadLimit: Int64
    var uploadLimit: Int64
    var listenPort: Int
    var portMapping: Bool
    var dht: Bool
    var pex: Bool
    var lsd: Bool
    var encryption: Encryption
    var peerProtocol: PeerProtocol
    var maxConnections: Int
    var maxConnectionsPerTorrent: Int
    var ratioLimitEnabled: Bool
    var ratioLimit: Double
    var ratioAction: RatioAction
    var queueingEnabled: Bool

    private enum CodingKeys: String, CodingKey {
        case upnp, dht, pex, lsd, encryption
        case savePath = "save_path"
        case downloadLimit = "dl_limit"
        case uploadLimit = "up_limit"
        case listenPort = "listen_port"
        case peerProtocol = "bittorrent_protocol"
        case maxConnections = "max_connec"
        case maxConnectionsPerTorrent = "max_connec_per_torrent"
        case ratioLimitEnabled = "max_ratio_enabled"
        case ratioLimit = "max_ratio"
        case ratioAction = "max_ratio_act"
        case queueingEnabled = "queueing_enabled"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        savePath = c.value(.savePath, default: "")
        downloadLimit = max(c.value(.downloadLimit, default: 0), 0)
        uploadLimit = max(c.value(.uploadLimit, default: 0), 0)
        listenPort = c.value(.listenPort, default: 0)
        portMapping = c.value(.upnp, default: true)
        dht = c.value(.dht, default: true)
        pex = c.value(.pex, default: true)
        lsd = c.value(.lsd, default: true)
        encryption = c.value(.encryption, default: .prefer)
        peerProtocol = c.value(.peerProtocol, default: .both)
        maxConnections = c.value(.maxConnections, default: 500)
        maxConnectionsPerTorrent = c.value(.maxConnectionsPerTorrent, default: 100)
        ratioLimitEnabled = c.value(.ratioLimitEnabled, default: false)
        ratioLimit = c.value(.ratioLimit, default: 2)
        ratioAction = c.value(.ratioAction, default: .stop)
        queueingEnabled = c.value(.queueingEnabled, default: false)
    }
}

/// A single preference value sent to `POST /api/v2/app/setPreferences`.
enum PreferenceValue: Encodable, Sendable {
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .bool(let value): try container.encode(value)
        case .int(let value): try container.encode(value)
        case .double(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        }
    }
}
