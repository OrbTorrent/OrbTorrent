import Foundation

/// Something keeping downloads from working as well as they could. There's
/// nothing to show while all is well.
enum ConnectionProblem: Equatable {
    case engineOffline
    case offline
    case incomingBlocked

    /// The engine calls itself disconnected for its first moments after
    /// launch, until it's listening, so being offline only counts once it
    /// has lasted this long.
    static let offlineGrace: TimeInterval = 10

    /// The engine calls itself firewalled from launch until the first peer
    /// connects in, so a block only counts once it has lasted this long
    /// while something needs peers.
    static let blockedGrace: TimeInterval = 180

    /// The problem with the engine's network, if there is one.
    /// - Parameters:
    ///   - since: when the engine began reporting this status.
    ///   - needsPeers: whether any download is looking for peers.
    static func current(status: TransferInfo.ConnectionStatus, since: Date?,
                        needsPeers: Bool, now: Date = .now) -> ConnectionProblem? {
        func lasted(_ grace: TimeInterval) -> Bool {
            since.map { now.timeIntervalSince($0) >= grace } ?? false
        }
        switch status {
        case .connected:
            return nil
        case .disconnected:
            return lasted(offlineGrace) ? .offline : nil
        case .firewalled:
            return needsPeers && lasted(blockedGrace) ? .incomingBlocked : nil
        }
    }

    var title: String {
        switch self {
        case .engineOffline: "Engine offline"
        case .offline: "Offline"
        case .incomingBlocked: "Incoming connections blocked"
        }
    }

    var explanation: String {
        switch self {
        case .engineOffline:
            "OrbTorrent's download engine isn't running. It restarts automatically; you can also restart it in Settings → Engine."
        case .offline:
            "OrbTorrent isn't connected to the internet right now."
        case .incomingBlocked:
            "Downloads work, but only peers with open ports can reach you, which can make downloads slower. This usually means your router or internet provider (for example carrier-grade NAT) blocks incoming connections. A public IP address from your provider, or a VPN with port forwarding, fixes it."
        }
    }
}
