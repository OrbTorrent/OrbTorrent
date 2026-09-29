import AppKit
import SwiftUI

/// Covers the library while the engine starts, or explains why it can't.
struct EngineStatusOverlay: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.engine.status {
        case .starting where !model.store.hasLoaded:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Starting download engine…")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .capsule)
        case .failed(let message):
            VStack(spacing: 14) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.orange)
                Text("The Download Engine Isn't Running")
                    .font(.title3.weight(.semibold))
                ScrollView {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: 140)
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Show Log") {
                            NSWorkspace.shared.open(EnginePaths.consoleLog)
                        }
                        .buttonStyle(.glass)
                        Button("Try Again") {
                            Task { await model.restartEngine() }
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .controlSize(.large)
            }
            .padding(24)
            .frame(width: 420)
            .glassEffect(.regular, in: .rect(cornerRadius: 24))
        default:
            EmptyView()
        }
    }
}
