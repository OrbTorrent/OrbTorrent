import Foundation

/// Global transfer statistics from `GET /api/v2/transfer/info`.
struct TransferInfo: Sendable, Decodable, Equatable {
    enum ConnectionStatus: String, Sendable, Decodable {
        /// The listening port is reachable from the internet.
        case connected
        /// Online, but no incoming connection has been seen (closed port, CGNAT, firewall).
        case firewalled
        case disconnected
    }

    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let sessionDownloaded: Int64
    let sessionUploaded: Int64
    let dhtNodes: Int
    let connectionStatus: ConnectionStatus

    static let zero = TransferInfo(downloadSpeed: 0, uploadSpeed: 0, sessionDownloaded: 0,
                                   sessionUploaded: 0, dhtNodes: 0, connectionStatus: .disconnected)

    private enum CodingKeys: String, CodingKey {
        case downloadSpeed = "dl_info_speed"
        case uploadSpeed = "up_info_speed"
        case sessionDownloaded = "dl_info_data"
        case sessionUploaded = "up_info_data"
        case dhtNodes = "dht_nodes"
        case connectionStatus = "connection_status"
    }

    init(downloadSpeed: Int64, uploadSpeed: Int64, sessionDownloaded: Int64, sessionUploaded: Int64,
         dhtNodes: Int, connectionStatus: ConnectionStatus) {
        self.downloadSpeed = downloadSpeed
        self.uploadSpeed = uploadSpeed
        self.sessionDownloaded = sessionDownloaded
        self.sessionUploaded = sessionUploaded
        self.dhtNodes = dhtNodes
        self.connectionStatus = connectionStatus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        downloadSpeed = c.value(.downloadSpeed, default: 0)
        uploadSpeed = c.value(.uploadSpeed, default: 0)
        sessionDownloaded = c.value(.sessionDownloaded, default: 0)
        sessionUploaded = c.value(.sessionUploaded, default: 0)
        dhtNodes = c.value(.dhtNodes, default: 0)
        connectionStatus = c.value(.connectionStatus, default: .disconnected)
    }
}
