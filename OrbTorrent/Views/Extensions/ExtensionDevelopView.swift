import AppKit
import SwiftUI

/// The Develop tab: the switch `orb` needs, building an extension with a
/// coding agent or by hand, and the extensions being built.
struct ExtensionDevelopView: View {
    @Environment(AppModel.self) private var model
    @State private var width: CGFloat = 0

    var body: some View {
        ScrollView {
            Group {
                if width >= 760 {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 24) { mainColumn }
                            .frame(maxWidth: .infinity)
                        Resources()
                            .frame(width: 260)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        mainColumn
                        Resources()
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
        .navigationSubtitle(model.extensions.registry.allowsDevelopment ? "Development extensions on" : "")
    }

    @ViewBuilder
    private var mainColumn: some View {
        DevelopmentSwitch()
        BuildAnExtension()
        LoadedForDevelopment()
    }
}

/// "Allow development extensions", which everything built here needs, and
/// whether `orb` is connected.
private struct DevelopmentSwitch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let isOn = model.extensions.registry.allowsDevelopment
        let watched = model.developmentServer.watchedNames.map { name in
            model.extensions.registry.named(name)?.title ?? name
        }
        HStack(spacing: 12) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.gray), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text("Allow development extensions")
                    .fontWeight(.medium)
                if isOn {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(watched.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                            .frame(width: 7, height: 7)
                        Text(LocalizedStringKey(watched.isEmpty
                             ? "On, waiting for `orb dev` or `orb run`"
                             : "`orb dev` is connected: \(ListFormatter.localizedString(byJoining: watched))"))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Text("Off. Turn it on so you, or your coding agent, can load what's being built.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Toggle("Allow development extensions", isOn: Binding(
                get: { isOn },
                set: { model.setAllowsDevelopmentExtensions($0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            .help("Lets `orb dev` and `orb run` load an extension from its folder. OrbTorrent asks before loading a folder the first time.")
        }
        .extensionPanel(padding: 12)
    }
}

/// The two ways to build an extension: ask a coding agent, or run the
/// commands yourself.
private struct BuildAnExtension: View {
    private enum Way: String, CaseIterable, Identifiable {
        case agent, yourself
        var id: Self { self }
        var title: String {
            switch self {
            case .agent: "With AI"
            case .yourself: "Yourself"
            }
        }
    }

    @AppStorage("extensionsBuildWay") private var way = Way.agent
    /// Kept while switching back and forth.
    @State private var request = ""

    var body: some View {
        ExtensionSection(title: "Build an Extension") {
            Picker("How to build it", selection: $way) {
                ForEach(Way.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        } content: {
            switch way {
            case .agent: BuildWithAI(request: $request)
            case .yourself: BuildItYourself()
            }
        }
    }
}

/// Building an extension by asking a coding agent: what to paste, and what
/// the user will be asked to allow along the way.
private struct BuildWithAI: View {
    @Environment(AppModel.self) private var model
    @Binding var request: String
    @State private var copied = false
    @State private var showsRequest = false

    private static let examples: [(label: String, request: String)] = [
        ("Hold .scr files", "Hold downloads that contain Windows screensaver (.scr) files, which are programs in disguise."),
        ("Discord when done", "Send a message to my Discord channel when a download finishes."),
        ("Warn about tiny films", "Warn when a film is smaller than 700 MB, since it's probably fake or poor quality."),
    ]

    var body: some View {
        let isEmpty = request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        VStack(alignment: .leading, spacing: 16) {
            Text("Say what it should do, and a coding agent such as Claude Code, Codex, Cursor or Gemini CLI writes it, tests it and tries it on your downloads. Nothing runs until you allow it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                TextField("What should it do?", text: $request, prompt: Text("What should it do? For example: hold downloads that contain .scr files"), axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                HStack(spacing: 6) {
                    Text("Try:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Self.examples, id: \.label) { example in
                        Button(example.label) { request = example.request }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(AgentPrompt.text(for: request), forType: .string)
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy for Your Agent", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isEmpty)
                    .help(isEmpty ? "Say what it should do first" : "Copy, then paste it into your coding agent")
                    Button(showsRequest ? "Hide the Request" : "Show the Request") {
                        withAnimation(.snappy) { showsRequest.toggle() }
                    }
                    .buttonStyle(.link)
                    .disabled(isEmpty)
                }
                if showsRequest && !isEmpty {
                    ScrollView {
                        Text(AgentPrompt.text(for: request))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(height: 150)
                    .background(.background.opacity(0.6), in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                }
                Text("Paste it into your agent, started in the folder where you keep your projects. It needs Node.js 22.13 or later, which your agent can install.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Along the way, you'll be asked to:")
                    .font(.callout.weight(.medium))
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 18, height: 18)
                            .background(.quaternary, in: .circle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.title)
                            Text(step.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .extensionPanel()
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }

    /// What only the user can do. Turning on development extensions is left
    /// out once it's on.
    private var steps: [(title: String, detail: String)] {
        var steps: [(title: String, detail: String)] = []
        if !model.extensions.registry.allowsDevelopment {
            steps.append(("Allow development extensions", "The switch at the top, so your agent can load what it builds."))
        }
        steps.append(("Allow your agent's folder", "OrbTorrent asks the first time your agent tries the extension on a download."))
        steps.append(("Confirm the install", "OrbTorrent shows what the extension does and what it can reach before you install it."))
        return steps
    }
}

/// The steps from nothing to a shared extension, with commands to copy.
private struct BuildItYourself: View {
    private struct Step {
        let title: String
        let command: String
        let detail: String
    }

    private static let steps = [
        Step(title: "Make an extension", command: "npm create @orbtorrent/extension@latest my-extension",
             detail: "Then `cd my-extension` and `npm install`. Add `-- --template after-finish` for a hook that runs once a download finishes. You need Node.js 22.13 or later."),
        Step(title: "Test it", command: "npm test",
             detail: "Runs the JSON tests in `tests/` without OrbTorrent, on a virtual clock."),
        Step(title: "Load it here", command: "npm run dev",
             detail: "Loads it into OrbTorrent and rebuilds on every save. It needs the switch at the top; if it can't connect, `npx orb doctor` says why."),
        Step(title: "Try it on a download", command: "npx orb run check --download \"name\"",
             detail: "Runs a hook on a real download and prints what it found. `npx orb downloads` lists yours."),
        Step(title: "Install it", command: "npx orb install",
             detail: "OrbTorrent shows what it does and what it can reach, and installs it when you confirm. It replaces the copy loaded for development."),
        Step(title: "Share it", command: "npx orb package",
             detail: "Makes an `.orbext` file that anyone with OrbTorrent can install."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.callout.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(step.title)
                            .fontWeight(.medium)
                        CommandBox(command: step.command)
                        Text(LocalizedStringKey(step.detail))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .extensionPanel()
    }
}

/// Extensions `orb` has loaded from their folders.
private struct LoadedForDevelopment: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let registry = model.extensions.registry
        let items = registry.extensions.filter { $0.source == .development }
        ExtensionSection("In Development") {
            if items.isEmpty {
                Text("Nothing yet. What you or your agent builds shows here once `orb` loads it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .extensionPanel()
            } else {
                VStack(spacing: 0) {
                    ForEach(items) { item in
                        row(item)
                        if item.id != items.last?.id { Divider() }
                    }
                }
                .extensionPanel(padding: 14)
            }
        }
    }

    private func row(_ item: InstalledExtension) -> some View {
        HStack(spacing: 12) {
            Button {
                model.extensionPath.append(item.name)
            } label: {
                HStack(spacing: 10) {
                    ExtensionIcon(url: item.iconURL, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.title)
                                .fontWeight(.medium)
                            if let tag = item.tag { ExtensionTag(text: tag) }
                        }
                        Text(item.folder.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help("Show its page")
            Button("Reload") { model.extensions.registry.reload() }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.folder]) }
        }
        .controlSize(.small)
        .padding(.vertical, 8)
    }
}

/// The guides, and what coding agents read.
private struct Resources: View {
    var body: some View {
        ExtensionSection("Resources") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(DeveloperLinks.guides, id: \.title) { guide in
                        link(guide.title, symbol: guide.symbol, to: guide.url)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("For Coding Agents")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    link("Agent Skill", symbol: "sparkles", to: DeveloperLinks.skill)
                    link("llms.txt", symbol: "text.alignleft", to: DeveloperLinks.llms)
                    Text("Every new extension has an `AGENTS.md` with everything an agent needs, and `orb doctor` tells it what's missing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .font(.callout)
            .extensionPanel()
        }
    }

    private func link(_ title: String, symbol: String, to url: URL) -> some View {
        Link(destination: url) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .frame(width: 18)
                Text(title)
            }
        }
    }
}

/// Where the developer docs live.
private enum DeveloperLinks {
    private static let base = "https://github.com/sanjevirau/OrbTorrent/blob/main/"
    static let skill = URL(string: base + "skills/build-orbtorrent-extension/SKILL.md")!
    static let llms = URL(string: base + "docs/extensions/llms.txt")!

    struct Guide {
        let title: String
        let symbol: String
        let url: URL
    }

    static let guides: [Guide] = [
        ("Getting Started", "flag", "getting-started"),
        ("Hooks", "arrow.triangle.branch", "hooks"),
        ("API", "curlybraces", "api"),
        ("Manifest", "doc.text", "manifest"),
        ("Testing", "checkmark.seal", "testing"),
        ("Sharing", "square.and.arrow.up", "sharing"),
        ("Security", "lock.shield", "security"),
    ].map { Guide(title: $0.0, symbol: $0.1, url: URL(string: base + "docs/extensions/\($0.2).md")!) }
}

/// What to paste into a coding agent to have it build an extension, from
/// what the user wants it to do.
enum AgentPrompt {
    /// In a file of its own, which scripts/agent-eval.mjs gives agents too.
    private static let template = Bundle.main.url(forResource: "AgentPrompt", withExtension: "txt")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""

    static func text(for request: String, isDevelopment: Bool = AppIdentity.isDevelopment) -> String {
        let app = isDevelopment ? "\nI'm using OrbTorrent Dev, so put `ORB_APP=dev` before every `npx orb` command.\n" : ""
        return template
            .replacingOccurrences(of: "{{app}}", with: app)
            .replacingOccurrences(of: "{{request}}", with: request.trimmingCharacters(in: .whitespacesAndNewlines))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A command in a box, with a button that copies it.
private struct CommandBox: View {
    let command: String
    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            Text(command)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 16)
            }
            .buttonStyle(.borderless)
            .help("Copy")
            .accessibilityLabel(copied ? "Copied" : "Copy \(command)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.background.opacity(0.6), in: .rect(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
