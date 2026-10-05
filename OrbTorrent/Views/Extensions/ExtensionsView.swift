import AppKit
import SwiftUI

/// The Extensions page in the main window: its tabs, and each extension's own
/// page.
struct ExtensionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.extensionPath) {
            Group {
                if !model.extensions.isOn {
                    ExtensionsOffView()
                } else {
                    switch model.extensionsTab {
                    case .installed: InstalledExtensionsView()
                    case .activity: ExtensionActivityView()
                    case .develop: ExtensionDevelopView()
                    }
                }
            }
            .navigationTitle("Extensions")
            .navigationDestination(for: String.self) { name in
                ExtensionPageView(name: name)
            }
        }
        .onAppear { model.extensions.registry.reload() }
        // Search looks through extensions or checks, so it leaves an
        // extension's page and the Develop tab.
        .onChange(of: model.extensionSearch) { _, text in
            guard !text.isEmpty else { return }
            model.extensionPath = []
            if model.extensionsTab == .develop { model.extensionsTab = .installed }
        }
    }
}

/// The page while extensions are off, with the way to turn them back on.
private struct ExtensionsOffView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ContentUnavailableView {
            Label("Extensions Are Off", systemImage: "puzzlepiece.extension")
        } description: {
            Text("OrbTorrent works as a plain torrent client: downloads aren't checked, and checks don't show. Your extensions and their settings are kept for when you turn them back on.")
                .font(.callout)
        } actions: {
            Button("Turn On Extensions") { model.setExtensionsOn(true) }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
        .navigationSubtitle("Off")
    }
}

/// The Installed tab: when extensions check a download, and every extension.
private struct InstalledExtensionsView: View {
    @Environment(AppModel.self) private var model

    private var registry: ExtensionRegistry { model.extensions.registry }
    private var search: String { model.extensionSearch.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if search.isEmpty {
                    CheckFlowView()
                    sections
                } else if !matches.isEmpty {
                    ExtensionGrid(items: matches)
                }
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .overlay {
            if !search.isEmpty && matches.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .navigationSubtitle(subtitle)
    }

    private var matches: [InstalledExtension] {
        registry.extensions.filter { item in
            [item.title, item.manifest.description, item.authorName].contains { $0.localizedStandardContains(search) }
        }
    }

    private var subtitle: String {
        let all = registry.extensions
        guard !all.isEmpty else { return "" }
        return "\(Format.count(all.count, "extension")) · \(all.filter(registry.isEnabled).count) on"
    }

    @ViewBuilder
    private var sections: some View {
        let official = registry.extensions.filter { $0.source == .official }
        let yours = registry.extensions.filter { $0.source != .official }

        if !official.isEmpty {
            ExtensionSection("Official") {
                ExtensionGrid(items: official)
            }
        }

        ExtensionSection(title: "Installed by You") {
            Button("Install Extension…") { model.chooseExtensionToInstall() }
        } content: {
            if yours.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("None yet")
                        .fontWeight(.medium)
                    HStack(spacing: 4) {
                        Text("Install one from an .orbext file someone shared, or")
                            .foregroundStyle(.secondary)
                        Button("build your own") { model.extensionsTab = .develop }
                            .buttonStyle(.link)
                    }
                    .font(.callout)
                }
                .extensionPanel()
            } else {
                ExtensionGrid(items: yours)
            }
        }

        if !registry.problems.isEmpty {
            ExtensionSection("Couldn't Load") {
                VStack(spacing: 10) {
                    ForEach(registry.problems) { ProblemPanel(problem: $0) }
                }
            }
        }
    }
}

/// The switch for every extension, above a download's life with the
/// extensions that check it at each point.
private struct CheckFlowView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The switch for all of them, above what they do.
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Check downloads with extensions")
                        .fontWeight(.medium)
                    Text("Turn off to use OrbTorrent as a plain torrent client. Your extensions and their settings are kept.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Toggle("Check downloads with extensions", isOn: Binding(
                    get: { model.extensions.isOn },
                    set: { model.setExtensionsOn($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            Divider()
                .padding(.horizontal, -16)
            HStack(alignment: .center, spacing: 0) {
                Milestone(title: "Added", symbol: "plus")
                Connector()
                Stage(event: .beforeStart)
                Connector()
                Milestone(title: "Downloading", symbol: "arrow.down")
                Connector()
                Stage(event: .afterFinish)
                // Reports on the checks, once an extension makes them.
                if model.extensions.registry.extensions.contains(where: { !$0.manifest.hooks(for: .afterChecks).isEmpty }) {
                    Connector()
                    Stage(event: .afterChecks)
                }
                Connector()
                Milestone(title: "Done", symbol: "checkmark")
            }
            .help("Extensions check each download, like the checks on a pull request. Before a download starts, a check can hold it until you decide. After it finishes, checks report what they find in its Checks tab. Once the checks are done, an extension can pass on what they found.")
        }
        .extensionPanel(padding: 16)
    }

    private struct Milestone: View {
        let title: String
        let symbol: String

        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.quaternary, in: .circle)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            // The line joins the circles' middles, not the captions'.
            .alignmentGuide(VerticalAlignment.center) { _ in 15 }
        }
    }

    private struct Connector: View {
        var body: some View {
            Capsule()
                .fill(.quaternary)
                .frame(height: 2)
                .frame(minWidth: 10, maxWidth: 28)
                .padding(.horizontal, 4)
        }
    }

    private struct Stage: View {
        @Environment(AppModel.self) private var model
        let event: ExtensionManifest.Event

        var body: some View {
            let registry = model.extensions.registry
            let items = registry.extensions.filter { item in
                registry.isEnabled(item) && item.manifest.hooks.contains { $0.event == event }
            }
            VStack(alignment: .leading, spacing: 8) {
                Label(event.stageTitle, systemImage: event.symbol)
                    .font(.subheadline.weight(.semibold))
                if items.isEmpty {
                    Text("No extension is on")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(items) { item in
                        Button {
                            model.extensionPath.append(item.name)
                        } label: {
                            HStack(spacing: 7) {
                                ExtensionIcon(url: item.iconURL, size: 18)
                                Text(item.title)
                                    .lineLimit(1)
                                if !model.extensions.settings.missing(for: item).isEmpty {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .help("Needs setup")
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: .rect(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: items.isEmpty ? [4, 3] : []))
            )
        }

        private var caption: String {
            switch event {
            case .beforeStart: "Can hold a download until you decide"
            case .afterFinish: "Reports what it finds"
            case .afterChecks: "Passes on what the checks found"
            }
        }
    }
}

/// Extensions as cards.
private struct ExtensionGrid: View {
    let items: [InstalledExtension]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 340), spacing: 14, alignment: .top)], spacing: 14) {
            ForEach(items) { ExtensionCard(item: $0) }
        }
    }
}

/// One extension: what it does, when it runs, how it's doing, and its switch.
private struct ExtensionCard: View {
    @Environment(AppModel.self) private var model
    let item: InstalledExtension
    @State private var isHovered = false

    private var registry: ExtensionRegistry { model.extensions.registry }

    var body: some View {
        Button {
            model.extensionPath.append(item.name)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ExtensionIcon(url: item.iconURL, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text("By \(item.authorName)")
                                .lineLimit(1)
                            if let tag = item.tag { ExtensionTag(text: tag) }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    // Room for the switch, which sits over the card.
                    Spacer(minLength: 52)
                }
                Text(item.manifest.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                Divider()
                HStack(spacing: 12) {
                    ForEach(item.events, id: \.self) { event in
                        Label(event.stageTitle, systemImage: event.symbol)
                    }
                    Spacer(minLength: 8)
                    status
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isHovered ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.quaternary.opacity(0.6))))
            .contentShape(.rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityHint("Shows the extension's page")
        .onHover { isHovered = $0 }
        .overlay(alignment: .topTrailing) {
            Toggle(item.title, isOn: Binding(get: { registry.isEnabled(item) }, set: { registry.setEnabled($0, for: item) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
                .disabled(!item.isCompatible)
                .padding(16)
        }
    }

    @ViewBuilder
    private var status: some View {
        let isOn = registry.isEnabled(item)
        if !item.isCompatible {
            Label("Needs a newer OrbTorrent", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        } else if isOn && !model.extensions.settings.missing(for: item).isEmpty {
            Label("Needs setup", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        } else if !isOn {
            Text("Off")
        } else if let usage {
            Text(usage)
        } else {
            Text("Hasn't run yet")
        }
    }

    /// How many downloads it has checked, and when it last did.
    private var usage: String? {
        var count = 0
        var last: Date?
        for entry in model.extensions.checks.entries.values {
            guard let record = entry.records.first(where: { $0.extensionName == item.name && $0.status.isFinished }) else { continue }
            count += 1
            if let finished = record.finishedAt, finished > (last ?? .distantPast) { last = finished }
        }
        guard count > 0 else { return nil }
        let checked = "Checked \(Format.count(count, "download"))"
        guard let last else { return checked }
        return "\(checked) · \(last.formatted(.relative(presentation: .named)))"
    }
}

/// A folder that should hold an extension but couldn't be loaded.
private struct ProblemPanel: View {
    let problem: ExtensionProblem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("“\(problem.folder.lastPathComponent)” couldn't be loaded")
                    .fontWeight(.medium)
                Text(problem.message)
                    .font(.callout)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text(problem.folder.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([problem.folder]) }
        }
        .extensionPanel()
    }
}
