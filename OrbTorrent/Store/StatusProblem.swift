import Foundation

/// What the menu bar panel and the sidebar say is wrong: first whatever has
/// stopped downloads, then the connection.
enum StatusProblem: Equatable {
    /// Downloads are waiting for space on these disks.
    case diskAlmostFull([String])
    /// Downloads only go through a VPN, and it isn't connected. Has the chosen
    /// VPN's name, or nil when any VPN will do.
    case waitingForVPN(String?)
    case connection(ConnectionProblem)

    /// The problem to show, if any.
    static func current(fullDisks: [String], vpn: VPNBinding.Status, vpnName: String?,
                        connection: ConnectionProblem?) -> StatusProblem? {
        if !fullDisks.isEmpty { return .diskAlmostFull(fullDisks) }
        // Without its VPN the engine calls itself offline, which it is on purpose.
        if vpn == .waitingForVPN { return .waitingForVPN(vpnName) }
        return connection.map(StatusProblem.connection)
    }

    var title: String {
        switch self {
        case .diskAlmostFull: "Disk almost full"
        case .waitingForVPN(let name): "Waiting for \(name ?? "VPN")"
        case .connection(let problem): problem.title
        }
    }

    var explanation: String {
        switch self {
        case .diskAlmostFull(let disks):
            let names = ListFormatter.localizedString(byJoining: disks.map { "“\($0)”" })
            return "Downloads saving to \(names) are paused so the disk doesn't fill up. They resume by themselves once it has \(Format.bytes(DiskSpace.resumeAt)) free."
        case .waitingForVPN(let name):
            let vpn = name ?? "a VPN"
            return "Downloads only go through \(vpn), and it isn't connected, so nothing is downloaded or shared over your normal connection. They continue once \(vpn) connects. You can change this in Settings → Network."
        case .connection(let problem):
            return problem.explanation
        }
    }
}
