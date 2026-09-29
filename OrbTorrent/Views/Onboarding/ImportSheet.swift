import AppKit
import SwiftUI

/// Brings over another app's downloads and settings, showing what comes over first.
struct ImportSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let source: ImportSource

    @State private var plan: ImportPlan?
    @State private var settings: [ImportedSetting] = []
    @State private var includesDownloads = true
    @State private var leftOut: Set<ImportedSetting.Kind> = []
    @State private var isSourceRunning = false
    @State private var phase = Phase.reviewing

    private enum Phase: Equatable {
        case reviewing
        case importing
        case finished(downloads: Int, settings: Int)
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            switch phase {
            case .reviewing, .importing:
                if let plan {
                    review(plan)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, minHeight: 80)
                }
            case .finished(let downloads, let settings):
                finished(downloads: downloads, settings: settings)
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            buttons
        }
        .padding(20)
        .frame(width: 480)
        .task { await load() }
        .task {
            // Quitting the app from its own window counts too.
            while !Task.isCancelled {
                isSourceRunning = source.isRunning
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            if let icon = source.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 56, height: 56)
            } else {
                TorrentIcon(symbol: "square.and.arrow.down.on.square", size: 56)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Import from \(source.name)")
                    .font(.title3.weight(.semibold))
                Text("Bring your downloads and settings over to OrbTorrent.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Review

    private func review(_ plan: ImportPlan) -> some View {
        Group {
            reviewContent(plan)
        }
        .disabled(phase == .importing)
    }

    @ViewBuilder
    private func reviewContent(_ plan: ImportPlan) -> some View {
        if plan.downloads.isEmpty && settings.isEmpty {
            Text("There's nothing new to bring over. OrbTorrent already has \(source.name)'s downloads, and its settings match.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            if !plan.downloads.isEmpty {
                ImportSection("Downloads") {
                    Toggle(isOn: $includesDownloads) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Format.count(plan.downloads.count, "download"))
                            // Up to four names, or three and how many more.
                            let shown = plan.downloads.count <= 4 ? plan.downloads : Array(plan.downloads.prefix(3))
                            Group {
                                ForEach(shown) { download in
                                    Text(download.name)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                if shown.count < plan.downloads.count {
                                    Text("and \(plan.downloads.count - shown.count) more")
                                }
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    Text(downloadsNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !settings.isEmpty {
                ImportSection("Settings") {
                    ForEach(settings) { setting in
                        HStack(alignment: .firstTextBaseline) {
                            Toggle(setting.title, isOn: isChosen(setting.kind))
                                .toggleStyle(.checkbox)
                            Spacer(minLength: 12)
                            Text(setting.value)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            if isSourceRunning {
                Label("\(source.name) quits when you import, so the two apps don't use the same files.",
                      systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var downloadsNote: String {
        switch source {
        case .transmission:
            "OrbTorrent checks their files before they go on, and those that were stopped stay stopped. Transmission keeps its own list."
        case .qBittorrent:
            "Their progress comes over as it is. qBittorrent keeps its own list."
        }
    }

    private func isChosen(_ kind: ImportedSetting.Kind) -> Binding<Bool> {
        Binding(
            get: { !leftOut.contains(kind) },
            set: { if $0 { leftOut.remove(kind) } else { leftOut.insert(kind) } }
        )
    }

    private var chosenSettings: [ImportedSetting] {
        settings.filter { !leftOut.contains($0.kind) }
    }

    private var hasSomethingChosen: Bool {
        (includesDownloads && plan?.downloads.isEmpty == false) || !chosenSettings.isEmpty
    }

    // MARK: Finished

    private func finished(downloads: Int, settings: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(summary(downloads: downloads, settings: settings), systemImage: "checkmark.circle.fill")
                .font(.headline)
                .symbolRenderingMode(.multicolor)
            if downloads > 0 && source == .transmission {
                Text("OrbTorrent is checking their files. Each goes on once it's checked, or stays stopped if it was stopped in Transmission.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func summary(downloads: Int, settings: Int) -> String {
        switch (downloads, settings) {
        case (0, 0): "Nothing new to bring over"
        case (_, 0): "Imported \(Format.count(downloads, "download"))"
        case (0, _): "Imported \(Format.count(settings, "setting"))"
        default: "Imported \(Format.count(downloads, "download")) and \(Format.count(settings, "setting"))"
        }
    }

    // MARK: Buttons

    private var buttons: some View {
        HStack {
            if phase == .importing {
                ProgressView()
                    .controlSize(.small)
                Text(isSourceRunning ? "Waiting for \(source.name) to quit…" : "Importing…")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            switch phase {
            case .reviewing, .importing:
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(phase == .importing)
                if plan.map({ !$0.downloads.isEmpty || !settings.isEmpty }) == true {
                    Button(isSourceRunning ? "Quit \(source.name) and Import" : "Import") {
                        Task { await runImport() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!hasSomethingChosen || phase == .importing)
                }
            case .finished, .failed:
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: Actions

    private func load() async {
        let plan = await model.importPlan(from: source)
        settings = model.importableSettings(in: plan)
        self.plan = plan
    }

    private func runImport() async {
        phase = .importing
        let chosen = chosenSettings
        do {
            let downloads = try await model.runImport(from: source, includingDownloads: includesDownloads, settings: chosen)
            phase = .finished(downloads: downloads, settings: chosen.count)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

/// A titled group of choices in the import sheet.
private struct ImportSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: .rect(cornerRadius: 10))
        }
    }
}
