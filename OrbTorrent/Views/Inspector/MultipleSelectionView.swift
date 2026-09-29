import SwiftUI

/// Inspector summary when several downloads are selected.
struct MultipleSelectionView: View {
    @Environment(AppModel.self) private var model
    let torrents: [Torrent]

    var body: some View {
        let size = torrents.reduce(Int64(0)) { $0 + $1.size }
        let left = torrents.reduce(Int64(0)) { $0 + $1.amountLeft }
        let anyRunning = torrents.contains { !$0.state.isStopped }

        VStack(spacing: 18) {
            Image(systemName: "square.stack.3d.down.right")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Text("\(torrents.count) Downloads Selected")
                    .font(.title3.weight(.semibold))
                Text("\(Format.bytes(size)) total · \(Format.bytes(left)) remaining")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button(anyRunning ? "Pause All" : "Resume All", systemImage: anyRunning ? "pause.fill" : "play.fill") {
                        Task { await model.store.togglePause(torrents) }
                    }
                    Button("Remove…", systemImage: "trash") {
                        model.requestRemoval(of: torrents)
                    }
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
