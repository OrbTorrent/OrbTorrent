import SwiftUI

/// The top of the menu bar panel: the orb, the app's name with any problem, or
/// the VPN downloads go through, under it, and the overall speeds.
struct MenuBarHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 10) {
            LiveOrb(state: model.orbState)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text("OrbTorrent")
                    .font(.headline)
                // Only when something's wrong; the engine stopping has its own message below.
                if model.engine.isRunning, let problem = model.problem {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(problem.tint)
                            .frame(width: 6, height: 6)
                        Text(problem.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .help(problem.explanation)
                } else if model.engine.isRunning, case .through(let connection) = model.vpn.status {
                    VPNBadge(name: connection.name)
                }
            }
            Spacer(minLength: 12)
            HStack(spacing: 12) {
                SpeedStat(direction: .down, bytesPerSecond: model.store.transfer.downloadSpeed)
                SpeedStat(direction: .up, bytesPerSecond: model.store.transfer.uploadSpeed)
            }
        }

    }
}
