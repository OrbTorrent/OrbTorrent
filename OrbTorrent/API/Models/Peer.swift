import Foundation

/// A connected peer, from `GET /api/v2/sync/torrentPeers`.
struct Peer: Identifiable, Hashable, Sendable, Decodable {
    /// "ip:port" as keyed by qBittorrent.
    var id: String { "\(ip):\(port)" }

    let ip: String
    let port: Int
    let client: String
    let connection: String
    let flags: String
    let flagsDescription: String
    let progress: Double
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let downloaded: Int64
    let uploaded: Int64
    let countryCode: String

    /// µTP connections run over UDP; plain "BT" is TCP.
    var isUTP: Bool { connection.contains("TP") && connection != "BT" }
    /// qBittorrent's "I" flag: the peer connected to us.
    var isIncoming: Bool { flags.split(separator: " ").contains("I") }
    var isEncrypted: Bool { flags.split(separator: " ").contains { $0 == "E" || $0 == "e" } }
    var isSeed: Bool { progress >= 1 }

    /// The flag of the peer's country, or nil when it isn't known, as for a
    /// peer on the local network.
    var countryFlag: String? {
        let code = countryCode.uppercased()
        guard Self.countries.contains(code) else { return nil }
        // A flag is its country's two letters as regional indicator symbols.
        var flag = String.UnicodeScalarView()
        for letter in code.unicodeScalars {
            guard let symbol = Unicode.Scalar(0x1F1E6 + letter.value - 0x41) else { return nil }
            flag.append(symbol)
        }
        return String(flag)
    }

    /// The peer's country, in the user's language.
    var countryName: String? {
        countryFlag == nil ? nil : Locale.current.localizedString(forRegionCode: countryCode.uppercased())
    }

    /// Real countries and regions, leaving out codes such as "ZZ", unknown.
    private static let countries = Set(Locale.Region.isoRegions.map(\.identifier))

    private enum CodingKeys: String, CodingKey {
        case ip, port, client, connection, flags, progress, downloaded, uploaded
        case flagsDescription = "flags_desc"
        case downloadSpeed = "dl_speed"
        case uploadSpeed = "up_speed"
        case countryCode = "country_code"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ip = c.value(.ip, default: "")
        port = c.value(.port, default: 0)
        client = c.value(.client, default: "")
        connection = c.value(.connection, default: "BT")
        flags = c.value(.flags, default: "")
        flagsDescription = c.value(.flagsDescription, default: "")
        progress = c.value(.progress, default: 0)
        downloadSpeed = c.value(.downloadSpeed, default: 0)
        uploadSpeed = c.value(.uploadSpeed, default: 0)
        downloaded = c.value(.downloaded, default: 0)
        uploaded = c.value(.uploaded, default: 0)
        countryCode = c.value(.countryCode, default: "")
    }
}

/// Response envelope of `sync/torrentPeers`.
struct PeersSnapshot: Decodable, Sendable {
    let peers: [String: Peer]

    private enum CodingKeys: String, CodingKey { case peers }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        peers = c.value(.peers, default: [:])
    }
}
