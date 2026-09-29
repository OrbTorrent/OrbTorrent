import AppKit
import SwiftUI

/// One extension's page: its switch and settings, what it has checked, what
/// it can do, and its logs.
struct ExtensionPageView: View {
    @Environment(AppModel.self) private var model
    let name: String

    var body: some View {
        if let item = model.extensions.registry.named(name) {
            ExtensionPageContent(item: item)
                .id(item.name + item.folder.path)
        } else {
            ContentUnavailableView("Extension Not Found", systemImage: "puzzlepiece.extension",
                                   description: Text("It was removed, or it couldn't load.").font(.callout))
        }
    }
}

private struct ExtensionPageContent: View {
    @Environment(AppModel.self) private var model
    let item: InstalledExtension
    @State private var width: CGFloat = 0
    @State private var isConfirmingRemoval = false

    private var extensions: Extensions { model.extensions }
    private var registry: ExtensionRegistry { extensions.registry }
    private var missing: [ExtensionManifest.Preference] { extensions.settings.missing(for: item) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                callout
                if width >= 760 {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 24) { mainColumn }
                            .frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 24) { sideColumn }
                            .frame(width: 300)
                    }
                } else {
                    mainColumn
                    sideColumn
                }
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .navigationTitle(item.title)
        .confirmationDialog(item.source == .development ? "Remove “\(item.title)”?" : "Uninstall “\(item.title)”?",
                            isPresented: $isConfirmingRemoval) {
            Button(item.source == .development ? "Remove" : "Uninstall", role: .destructive) {
                registry.remove(item)
                if registry.named(item.name) == nil { model.extensionPath.removeAll { $0 == item.name } }
            }
        } message: {
            Text(item.replacesOfficial
                 ? "The official extension takes its place again."
                 : "Its settings, including any API key, are deleted too.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 18) {
            ExtensionIcon(url: item.iconURL, size: 76)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.title.weight(.semibold))
                    if let tag = item.tag { ExtensionTag(text: tag) }
                }
                Text(item.byline)
                    .foregroundStyle(.secondary)
                Text(item.manifest.description)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
                HStack(spacing: 14) {
                    ForEach(item.events, id: \.self) { event in
                        Label(event.stageTitle, systemImage: event.symbol)
                    }
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            }
            Spacer(minLength: 12)
            Toggle(item.title, isOn: Binding(get: { registry.isEnabled(item) }, set: { registry.setEnabled($0, for: item) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!item.isCompatible)
                .help(registry.isEnabled(item) ? "Turn off" : "Turn on")
        }
    }

    @ViewBuilder
    private var callout: some View {
        if !item.isCompatible {
            Callout(text: "It needs a newer version of OrbTorrent, so it doesn't run.")
        } else if registry.isEnabled(item) && !missing.isEmpty {
            let names = missing.map { $0.kind == .password ? "your \($0.title)" : $0.title }
            Callout(text: "Needs setup: add \(ListFormatter.localizedString(byJoining: names)). Its checks are skipped until then.")
        }
    }

    private struct Callout: View {
        let text: String

        var body: some View {
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.3)))
        }
    }

    // MARK: Columns

    @ViewBuilder
    private var mainColumn: some View {
        if !item.manifest.preferences.isEmpty {
            ExtensionSection("Settings") {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(item.manifest.preferences) { preference in
                        PreferenceField(item: item, preference: preference)
                    }
                    if item.manifest.verify != nil {
                        Divider()
                        VerifyButton(item: item)
                    }
                }
                .extensionPanel()
            }
        }
        recentChecks
        logs
    }

    @ViewBuilder
    private var sideColumn: some View {
        if let help = item.help {
            ExtensionSection("How to Set It Up") {
                MarkdownText(help)
                    .font(.callout)
                    .extensionPanel()
            }
        }
        ExtensionSection("Runs") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(item.manifest.hooks) { hook in
                    VStack(alignment: .leading, spacing: 3) {
                        Label(hook.title, systemImage: hook.event.symbol)
                            .fontWeight(.medium)
                        Text(hook.event.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let description = hook.description {
                            Text(description)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .extensionPanel()
        }
        ExtensionSection("Can") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(item.manifest.abilities, id: \.self) { ability in
                    Label(ability, systemImage: ExtensionManifest.symbol(for: ability))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if item.source != .official {
                    Text("Not reviewed by OrbTorrent. OrbTorrent enforces this list: it can't read other files or reach other sites.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)
            .extensionPanel()
        }
        about
    }

    // MARK: Sections

    private var recentChecks: some View {
        let checks = RecentCheck.list(from: extensions.checks, names: { model.store.torrent($0)?.name },
                                      extension: item.name, limit: 10)
        return ExtensionSection(title: "Recent Checks") {
            if !checks.isEmpty {
                Button("Show All") { model.showActivity(of: item.name) }
            }
        } content: {
            if checks.isEmpty {
                Text(registry.isEnabled(item) ? "It hasn't checked a download yet." : "Turn it on to check your downloads.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .extensionPanel()
            } else {
                VStack(spacing: 0) {
                    ForEach(checks) { check in
                        RecentCheckRow(check: check, showsExtension: false)
                        if check.id != checks.last?.id { Divider() }
                    }
                }
                .extensionPanel(padding: 14)
            }
        }
    }

    private var logs: some View {
        let entries = extensions.logs.entries[item.name] ?? []
        return ExtensionSection(title: "Logs") {
            HStack(spacing: 14) {
                if !entries.isEmpty {
                    Button("Clear") { extensions.logs.clear(item.name) }
                }
                Button("Show Log File") {
                    NSWorkspace.shared.activateFileViewerSelecting([ExtensionPaths.log(of: item.name)])
                }
            }
        } content: {
            Group {
                if entries.isEmpty {
                    Text("Nothing logged since OrbTorrent started.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(entries) { entry in
                                Text("\(entry.date.formatted(date: .omitted, time: .standard))  \(entry.download.map { "[\($0)] " } ?? "")\(entry.message)")
                                    .foregroundStyle(entry.level == "error" ? .red : entry.level == "warn" ? .orange : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                    }
                    .frame(height: 180)
                    .defaultScrollAnchor(.bottom)
                }
            }
            .extensionPanel(padding: 14)
        }
    }

    private var about: some View {
        ExtensionSection("About") {
            VStack(alignment: .leading, spacing: 12) {
                VStack(spacing: 0) {
                    ForEach(Array(details.enumerated()), id: \.offset) { index, detail in
                        if index > 0 { Divider() }
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            Text(detail.label)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                            Spacer(minLength: 8)
                            Text(detail.value)
                                .multilineTextAlignment(.trailing)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                                .textSelection(.enabled)
                        }
                        .padding(.vertical, 7)
                    }
                }
                .font(.callout)
                if item.source != .official {
                    Text(item.folder.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    HStack(spacing: 8) {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.folder]) }
                        if item.source == .development {
                            Button("Reload") { registry.reload() }
                        }
                        Spacer(minLength: 0)
                        Button(item.source == .development ? "Remove…" : "Uninstall…", role: .destructive) {
                            isConfirmingRemoval = true
                        }
                    }
                    .controlSize(.small)
                }
            }
            .extensionPanel()
        }
    }

    /// What About lists, as label and value.
    private var details: [(label: String, value: String)] {
        var rows: [(label: String, value: String)] = []
        if let version = item.manifest.version { rows.append(("Version", version)) }
        rows.append(("Author", item.authorName))
        rows.append(("Source", source))
        if let license = item.manifest.license { rows.append(("License", license)) }
        if let api = item.manifest.apiVersion { rows.append(("Built for", "Extension API \(api)")) }
        return rows
    }

    private var source: String {
        switch item.source {
        case .official: "Comes with OrbTorrent"
        case .installed: "Installed by you"
        case .development: item.replacesOfficial ? "Development copy of the official extension" : "Loaded for development by orb"
        }
    }
}
