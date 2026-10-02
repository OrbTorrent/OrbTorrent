import SwiftUI

/// Exactly what the next update check sends, value by value, with what each
/// one means, as the settings stand.
struct SentCountsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let values = model.countsPreview()
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                TorrentIcon(symbol: "chart.bar.fill", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("What's Sent")
                        .font(.title2.weight(.bold))
                    Text("With the daily update check, to updates.orbtorrent.com")
                        .foregroundStyle(.secondary)
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    group("Every check", rows: [(meaning: "OrbTorrent's version and build", value: version)]
                          + values.map { ($0.meaning, $0.shown) })
                    if !values.isEmpty {
                        Text("As sent: updates.orbtorrent.com/appcast.xml?" + values.map { "\($0.key)=\($0.value)" }.joined(separator: "&"))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            Text(values.isEmpty
                 ? "Anonymous counts are off, so a check says only which version of OrbTorrent it is. The address a check comes from isn't kept."
                 : "Never an ID, your IP address, or anything about your downloads or how you use OrbTorrent. The address a check comes from isn't kept.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Link("About the Counts", destination: Website.counts)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        // Fits inside the Settings window, below its toolbar.
        .frame(width: 480, height: 390)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        return "\(version) (\(Updates.build))"
    }

    private func group(_ title: String, rows: [(meaning: String, value: String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 6) {
                ForEach(rows, id: \.meaning) { row in
                    GridRow {
                        Text(row.meaning)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(row.value)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.trailing)
                            .gridColumnAlignment(.trailing)
                    }
                    Divider()
                }
            }
        }
    }
}
