import AppKit
import SwiftUI

/// The Develop tab: building an extension with a coding agent or by hand,
/// the switch `orb` needs, and the extensions being built.
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
                        VStack(alignment: .leading, spacing: 24) { sideColumn }
                            .frame(width: 300)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        mainColumn
                        sideColumn
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
        BuildWithAI()
        DevelopmentSwitch()
        LoadedForDevelopment()
        GetStarted()
    }

    @ViewBuilder
    private var sideColumn: some View {
        ExtensionSection("For Coding Agents") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Every new extension has an `AGENTS.md`: the whole API, the rules and the loop in one file, with a `CLAUDE.md` that points to it.")
                Text("Every `orb` command takes `--json` and never prompts, so an agent can build, test and run an extension by itself. `orb doctor` tells it what's missing, and which steps only you can take.")
                VStack(alignment: .leading, spacing: 6) {
                    Link("Agent Skill", destination: DeveloperLinks.skill)
                    Link("llms.txt", destination: DeveloperLinks.llms)
                }
                .padding(.top, 2)
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .extensionPanel()
        }
        ExtensionSection("Documentation") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(DeveloperLinks.guides, id: \.title) { guide in
                    Link(destination: guide.url) {
                        HStack(spacing: 8) {
                            Image(systemName: guide.symbol)
                                .frame(width: 18)
                            Text(guide.title)
                        }
                    }
                }
            }
            .font(.callout)
            .extensionPanel()
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

/// "Allow development extensions", and whether `orb` is connected.
private struct DevelopmentSwitch: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let isOn = model.extensions.registry.allowsDevelopment
        let watched = model.developmentServer.watchedNames.map { name in
            model.extensions.registry.named(name)?.title ?? name
        }
        ExtensionSection("Development") {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.tint, in: .rect(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Allow development extensions")
                        .fontWeight(.medium)
                    Text("Lets `orb dev` and `orb run` load the extension you're building. OrbTorrent asks before loading a folder the first time.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if isOn {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(watched.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.green))
                                .frame(width: 7, height: 7)
                            Text(LocalizedStringKey(watched.isEmpty
                                 ? "Waiting for `orb dev` or `orb run`"
                                 : "`orb dev` is connected: \(ListFormatter.localizedString(byJoining: watched))"))
                        }
                        .font(.callout)
                        .padding(.top, 4)
                    }
                }
                Spacer(minLength: 12)
                Toggle("Allow development extensions", isOn: Binding(
                    get: { isOn },
                    set: { model.setAllowsDevelopmentExtensions($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .extensionPanel()
        }
    }
}

/// Extensions `orb` has loaded from their folders.
private struct LoadedForDevelopment: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let registry = model.extensions.registry
        let items = registry.extensions.filter { $0.source == .development }
        ExtensionSection("Loaded for Development") {
            if items.isEmpty {
                Text("Nothing yet. Run `npm run dev` in an extension's folder to load it here.")
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

/// Building an extension by asking a coding agent: what to paste, and what
/// the user will be asked to allow along the way.
private struct BuildWithAI: View {
    @Environment(AppModel.self) private var model
    @State private var request = ""
    @State private var copied = false

    private static let examples: [(label: String, request: String)] = [
        ("Hold .scr files", "Hold downloads that contain Windows screensaver (.scr) files, which are programs in disguise."),
        ("Discord when done", "Send a message to my Discord channel when a download finishes."),
        ("Warn about tiny films", "Warn when a film is smaller than 700 MB, since it's probably fake or poor quality."),
    ]

    var body: some View {
        let isEmpty = request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ExtensionSection("Build with AI") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(.tint, in: .rect(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ask your coding agent to build it")
                            .fontWeight(.medium)
                        Text("Claude Code, Codex, Cursor, Gemini CLI and other coding agents can build an extension for you. Your agent writes it and tests it, tries it on one of your downloads, then asks OrbTorrent to install it. Nothing runs until you allow it here.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should it do?")
                        .font(.callout.weight(.medium))
                    TextField("What should it do?", text: $request, prompt: Text("Hold downloads that contain .scr files"), axis: .vertical)
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
                    HStack(alignment: .firstTextBaseline) {
                        Text("What to tell your agent")
                            .font(.callout.weight(.medium))
                        Spacer(minLength: 8)
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
                    }
                    ScrollView {
                        Text(AgentPrompt.text(for: isEmpty ? "…" : request))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                    }
                    .frame(height: 150)
                    .background(.background.opacity(0.6), in: .rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary))
                    Text("Paste it into your agent, started in the folder where you keep your projects. It needs Node.js 22.13 or later, which your agent can install.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Along the way, you'll be asked to:")
                        .font(.callout.weight(.medium))
                    allowStep
                    step(2, "Allow your agent's folder", "OrbTorrent asks the first time your agent tries the extension on a download.")
                    step(3, "Confirm the install", "OrbTorrent shows what the extension does and what it can reach before you install it.")
                }
            }
            .extensionPanel()
            .task(id: copied) {
                guard copied else { return }
                try? await Task.sleep(for: .seconds(2))
                copied = false
            }
        }
    }

    /// Turning on development extensions, with the switch right there.
    private var allowStep: some View {
        let isOn = model.extensions.registry.allowsDevelopment
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            number(1)
            VStack(alignment: .leading, spacing: 2) {
                Text("Allow development extensions")
                Text("So your agent can load what it builds. It's the switch below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if isOn {
                Label("On", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Button("Turn On") { model.setAllowsDevelopmentExtensions(true) }
                    .controlSize(.small)
            }
        }
    }

    private func step(_ index: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            number(index)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func number(_ index: Int) -> some View {
        Text("\(index)")
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
            .background(.quaternary, in: .circle)
    }
}

/// The steps from nothing to a shared extension, with commands to copy.
private struct GetStarted: View {
    private struct Step {
        let title: String
        let command: String
        let detail: String
    }

    private static let steps = [
        Step(title: "Make an extension", command: "npm create @orbtorrent/extension my-extension",
             detail: "Then `cd my-extension` and `npm install`. Add `-- --template after-finish` for a hook that runs once a download finishes. You need Node.js 22.13 or later."),
        Step(title: "Test it", command: "npm test",
             detail: "Runs the JSON tests in `tests/` without OrbTorrent, on a virtual clock."),
        Step(title: "Load it here", command: "npm run dev",
             detail: "Loads it into OrbTorrent and rebuilds on every save. It needs the switch above; if it can't connect, `npx orb doctor` says why."),
        Step(title: "Try it on a download", command: "npx orb run check --download \"name\"",
             detail: "Runs a hook on a real download and prints what it found. `npx orb downloads` lists yours."),
        Step(title: "Install it", command: "npx orb install",
             detail: "OrbTorrent shows what it does and what it can reach, and installs it when you confirm. It replaces the copy loaded for development."),
        Step(title: "Share it", command: "npx orb package",
             detail: "Makes an `.orbext` file that anyone with OrbTorrent can install."),
    ]

    var body: some View {
        ExtensionSection("Build It Yourself") {
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
