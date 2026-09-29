import AppKit
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let orbExtension = UTType(exportedAs: "com.orbtorrent.extension")
}

extension InstalledExtension {
    var authorName: String {
        manifest.author == "orbtorrent" ? "OrbTorrent" : manifest.author
    }

    /// Where it came from, when that's worth saying.
    var tag: String? {
        switch source {
        case .official: nil
        case .installed: "Not reviewed"
        case .development: replacesOfficial ? "Development copy" : "Development"
        }
    }

    var byline: String {
        let source = switch source {
        case .official: "Official"
        case .installed: "Not reviewed by OrbTorrent"
        case .development: replacesOfficial ? "Development copy of the official extension" : "Development"
        }
        return "By \(authorName) · \(source)"
    }

    /// The moments it runs at, in the order a download reaches them.
    var events: [ExtensionManifest.Event] {
        ExtensionManifest.Event.allCases.filter { event in manifest.hooks.contains { $0.event == event } }
    }
}

extension ExtensionManifest.Event {
    /// Where it sits in a download's life, for the Extensions page.
    var stageTitle: String {
        switch self {
        case .beforeStart: "Before it starts"
        case .afterFinish: "After it finishes"
        }
    }

    var symbol: String {
        switch self {
        case .beforeStart: "hand.raised"
        case .afterFinish: "flag.checkered"
        }
    }
}

extension ExtensionManifest {
    static func symbol(for ability: String) -> String {
        if ability.hasPrefix("Connect") { return "network" }
        if ability.hasPrefix("Hold") { return "hand.raised" }
        if ability.hasPrefix("Read") { return "doc.text.magnifyingglass" }
        return "list.bullet"
    }
}

extension View {
    /// The rounded panel the Extensions page groups things in.
    func extensionPanel(padding: CGFloat = 16, cornerRadius: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quinary, in: .rect(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).strokeBorder(.quaternary.opacity(0.6)))
    }
}

/// A heading with a panel under it.
struct ExtensionSection<Content: View, Accessory: View>: View {
    let title: String
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer(minLength: 8)
                accessory
                    .font(.callout)
                    .buttonStyle(.link)
            }
            .padding(.horizontal, 4)
            content
        }
    }
}

extension ExtensionSection where Accessory == EmptyView {
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        accessory = EmptyView()
        self.content = content()
    }
}

/// "Not reviewed" or "Development" beside an extension's name.
struct ExtensionTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: .capsule)
    }
}

/// An extension's icon, or a plain one.
struct ExtensionIcon: View {
    let url: URL?
    var size: CGFloat = 24

    private static let cache = NSCache<NSURL, NSImage>()

    var body: some View {
        if let image = url.flatMap(Self.image) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(.quaternary)
                .frame(width: size * 0.84, height: size * 0.84)
                .overlay(Image(systemName: "puzzlepiece.extension.fill").font(.system(size: size * 0.4)).foregroundStyle(.secondary))
                .frame(width: size, height: size)
        }
    }

    private static func image(_ url: URL) -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// A check an extension ran on a download, for the Extensions page.
struct RecentCheck: Identifiable {
    let hash: String
    let downloadName: String
    let record: CheckRecord

    var id: String { "\(hash)/\(record.id)" }
    var extensionTitle: String { record.extensionTitle }

    /// When it finished; checks still running count as now.
    var date: Date {
        record.status.isFinished ? (record.finishedAt ?? record.startedAt ?? .distantPast) : .distantFuture
    }

    /// What it found, or what it's doing.
    var summary: String { record.displaySummary }

    /// Worst first when sorted from the top.
    var severity: Int {
        switch record.status {
        case .failed: 6
        case .warning: 5
        case .didNotFinish: 4
        case .running, .queued: 3
        case .skipped: 2
        case .passed: 1
        }
    }

    var isProblem: Bool {
        [.failed, .warning, .didNotFinish].contains(record.status)
    }

    /// The newest first, with checks still running at the top.
    @MainActor
    static func list(from checks: ChecksStore, names: (String) -> String?, extension name: String? = nil, limit: Int? = nil) -> [RecentCheck] {
        var found: [RecentCheck] = []
        for (hash, entry) in checks.entries {
            guard let downloadName = names(hash) else { continue }
            for record in entry.records where name == nil || record.extensionName == name {
                found.append(RecentCheck(hash: hash, downloadName: downloadName, record: record))
            }
        }
        let sorted = found.sorted { $0.date > $1.date }
        return limit.map { Array(sorted.prefix($0)) } ?? sorted
    }
}

/// One check in a list, opening the download's Checks tab.
struct RecentCheckRow: View {
    @Environment(AppModel.self) private var model
    let check: RecentCheck
    /// Off on an extension's own page, where it would repeat.
    var showsExtension = true

    var body: some View {
        let record = check.record
        Button {
            model.showChecks(of: check.hash)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                CheckStatusIcon(status: record.status)
                VStack(alignment: .leading, spacing: 2) {
                    Text(check.downloadName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(showsExtension ? "\(record.extensionTitle): \(check.summary)" : check.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                if record.status.isFinished, let finished = record.finishedAt {
                    Text(finished, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 9)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Show this download's checks")
    }
}

/// One setting, drawn from the manifest.
struct PreferenceField: View {
    @Environment(AppModel.self) private var model
    let item: InstalledExtension
    let preference: ExtensionManifest.Preference
    @State private var password = ""
    @State private var error: String?

    private var settings: ExtensionSettings { model.extensions.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if preference.kind != .checkbox {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(preference.title)
                        .fontWeight(.medium)
                    if preference.isRequired {
                        Text("Required")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            control
            if let description = preference.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var control: some View {
        switch preference.kind {
        case .textfield:
            TextField("", text: Binding(get: { settings.value(of: preference, in: item.name).string ?? "" },
                                        set: { settings.set(.string($0), for: preference, in: item.name) }),
                      prompt: preference.placeholder.map(Text.init))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
        case .password:
            passwordField
        case .checkbox:
            Toggle(preference.label ?? preference.title, isOn: Binding(
                get: { settings.value(of: preference, in: item.name).bool ?? false },
                set: { settings.set(.bool($0), for: preference, in: item.name) }
            ))
            .toggleStyle(.checkbox)
        case .dropdown:
            Picker(preference.title, selection: Binding(get: { settings.value(of: preference, in: item.name).string ?? "" },
                                                        set: { settings.set(.string($0), for: preference, in: item.name) })) {
                ForEach(preference.options, id: \.value) { Text($0.title).tag($0.value) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }

    private var passwordField: some View {
        let isSaved = settings.hasPassword(preference, in: item.name)
        return HStack(spacing: 8) {
            SecureField("", text: $password, prompt: Text(isSaved ? "Saved in your Keychain" : (preference.placeholder ?? "")))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .onSubmit(save)
            if !password.isEmpty {
                Button("Save", action: save)
            } else if isSaved {
                Button("Remove") { try? settings.setPassword("", for: preference, in: item.name) }
            }
        }
    }

    private func save() {
        do {
            try settings.setPassword(password, for: preference, in: item.name)
            password = ""
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Checks the settings with the extension's own `verify`.
struct VerifyButton: View {
    @Environment(AppModel.self) private var model
    let item: InstalledExtension
    @State private var isVerifying = false
    @State private var result: (ok: Bool, message: String)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button("Verify") {
                isVerifying = true
                result = nil
                Task {
                    result = await model.extensions.verify(item)
                    isVerifying = false
                }
            }
            .disabled(isVerifying)
            if isVerifying {
                ProgressView().controlSize(.small)
            } else if let result {
                Label(result.message, systemImage: result.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result.ok ? .green : .red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// Asks before installing an extension, showing what it can do.
struct ExtensionInstallSheet: View {
    let candidate: ExtensionCandidate
    let finish: (Bool) -> Void

    private var item: InstalledExtension { candidate.extension }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ExtensionIcon(url: item.iconURL, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.existing == nil ? "Install “\(item.title)”?" : "Update “\(item.title)”?")
                        .font(.title3.weight(.semibold))
                    Text("By \(item.manifest.author) · Not reviewed by OrbTorrent")
                        .foregroundStyle(.secondary)
                    Text(item.manifest.description)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Runs").font(.headline)
                ForEach(item.manifest.hooks) { hook in
                    Label("\(hook.title): \(hook.event.title.lowercased())", systemImage: hook.event.symbol)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Can").font(.headline)
                ForEach(item.manifest.abilities, id: \.self) { ability in
                    HStack(spacing: 6) {
                        Label(ability, systemImage: ExtensionManifest.symbol(for: ability))
                        if candidate.newAbilities.contains(ability) {
                            Text("New")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.orange.opacity(0.2), in: .capsule)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            Text("Only install extensions from people you trust. OrbTorrent enforces these limits, but it hasn't reviewed the code.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { finish(false) }
                    .keyboardShortcut(.cancelAction)
                Button(candidate.existing == nil ? "Install" : "Update") { finish(true) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
