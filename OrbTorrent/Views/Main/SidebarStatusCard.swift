import SwiftUI

/// Overall speeds, and what's wrong when something is, or the VPN downloads
/// go through.
struct SidebarStatusCard: View {
    @Environment(AppModel.self) private var model
    @State private var showsConnectionHelp = false

    var body: some View {
        let transfer = model.store.transfer
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                SpeedStat(direction: .down, bytesPerSecond: transfer.downloadSpeed)
                SpeedStat(direction: .up, bytesPerSecond: transfer.uploadSpeed)
            }

            if let problem {
                Button {
                    showsConnectionHelp.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(problem.tint)
                            .frame(width: 7, height: 7)
                        Text(problem.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "info.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showsConnectionHelp, arrowEdge: .trailing) {
                    Text(problem.explanation)
                        .font(.callout)
                        .padding()
                        .frame(width: 280)
                }
            } else if case .through(let connection) = model.vpn.status {
                VPNBadge(name: connection.name, spacing: 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var problem: StatusProblem? { model.problem }
}
