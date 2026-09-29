import AppKit
import SwiftUI

/// OrbTorrent's name, version and copyright, with the software it's built
/// from, what it connects to, and its source. Shown in its own window, from
/// the app menu and the menu bar, and in Settings.
struct AboutView: View {
    @State private var sheet: Sheet?

    private enum Sheet: String, Identifiable {
        case acknowledgements, privacy
        var id: String { rawValue }
    }

    static let sourceURL = URL(string: "https://github.com/sanjevirau/OrbTorrent")!

    var body: some View {
        VStack(spacing: 0) {
            LiveOrb(state: .idle)
                .frame(width: 96, height: 96)
            Text(AppIdentity.name)
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 16)
            Text("Version \(Self.version)")
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .padding(.top, 2)
            Text("A fast, native torrent app for your Mac, powered by qBittorrent.")
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    Button("Acknowledgements") { sheet = .acknowledgements }
                    Button("Privacy") { sheet = .privacy }
                    Button("Source Code") { NSWorkspace.shared.open(Self.sourceURL) }
                }
                .buttonStyle(.glass)
            }
            .padding(.top, 20)

            VStack(spacing: 6) {
                Text("Copyright © 2026 Sanjevi Rau")
                Text("OrbTorrent is free software: you can share and change it under the GNU General Public License, version 3 or later. It comes with no warranty.")
                Text("It isn't affiliated with the qBittorrent project. Download only what you have the right to share.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 22)
        }
        .padding(.horizontal, 32)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .frame(width: 440)
        .sheet(item: $sheet) { sheet in
            switch sheet {
            case .acknowledgements: AcknowledgementsView()
            case .privacy: PrivacyView()
            }
        }
    }

    /// Such as "1.0 (1)".
    nonisolated static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }
}

// MARK: - Acknowledgements

/// The software OrbTorrent is built from, each with its licence.
struct AcknowledgementsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Acknowledgement.ID? = Acknowledgement.all[0].id

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                List(Acknowledgement.all, selection: $selection) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.body.weight(.medium))
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.sidebar)
                .frame(width: 210)
                Divider()
                // Licences are laid out in lines of up to 80 characters, so
                // they're shown as they are, never rewrapped.
                ScrollView([.vertical, .horizontal]) {
                    Text(Acknowledgement.all.first { $0.id == selection }?.text ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .id(selection)
            }
            Divider()
            HStack {
                Button("Show Licence Files") {
                    if let folder = Acknowledgement.folder { NSWorkspace.shared.open(folder) }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 780, height: 500)
    }
}

/// A piece of software OrbTorrent includes, and where its licence is in the app.
struct Acknowledgement: Identifiable {
    let name: String
    let licence: String
    /// The licence's file in the app's Licenses folder.
    let file: String
    /// How the engine's version list names it, or nil for OrbTorrent itself.
    let listedAs: String?
    var note: String?

    var id: String { name }

    static let all = [
        Acknowledgement(name: "OrbTorrent", licence: "GPL 3.0 or later", file: "OrbTorrent-LICENSE.txt", listedAs: nil),
        Acknowledgement(name: "qBittorrent", licence: "GPL 2.0 or later", file: "qBittorrent-COPYING.txt", listedAs: "qBittorrent"),
        Acknowledgement(name: "libtorrent", licence: "BSD 3-Clause", file: "libtorrent-LICENSE.txt", listedAs: "libtorrent-rasterbar"),
        Acknowledgement(name: "Qt", licence: "LGPL 3.0", file: "Qt/LGPL-3.0-only.txt", listedAs: "Qt",
                        note: "Parts of Qt come from other projects, each with its own notice. They're all in the licence files."),
        Acknowledgement(name: "OpenSSL", licence: "Apache 2.0", file: "OpenSSL-LICENSE.txt", listedAs: "OpenSSL"),
        Acknowledgement(name: "Boost", licence: "Boost Software License 1.0", file: "Boost-LICENSE_1_0.txt", listedAs: "Boost"),
        Acknowledgement(name: "Sparkle", licence: "MIT", file: "Sparkle-LICENSE.txt", listedAs: "Sparkle",
                        note: "Sparkle keeps OrbTorrent up to date. Parts of it come from other projects, each with its notice below."),
    ]

    static var folder: URL? { Bundle.main.resourceURL?.appending(path: "Licenses", directoryHint: .isDirectory) }

    /// The engine's components and versions, one per line, such as "Qt 6.10.3 (qtbase, static)".
    static let engineVersions: [String] = folder
        .flatMap { try? String(contentsOf: $0.appending(path: "ENGINE-VERSIONS.txt"), encoding: .utf8) }?
        .components(separatedBy: .newlines) ?? []

    /// OrbTorrent's own, the engine's list, or a framework's bundle.
    var version: String? {
        guard let listedAs else { return AboutView.version }
        return Self.engineVersions.first { $0.hasPrefix(listedAs + " ") }?
            .dropFirst(listedAs.count + 1)
            .split(separator: " ").first.map(String.init)
            ?? Bundle.main.privateFrameworksURL
            .flatMap { Bundle(url: $0.appending(path: "\(listedAs).framework")) }?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// Such as "6.10.3 · LGPL 3.0".
    var detail: String {
        [version, licence].compactMap(\.self).joined(separator: " · ")
    }

    var text: String {
        let licence = Self.folder.flatMap { try? String(contentsOf: $0.appending(path: file), encoding: .utf8) }
            ?? "This copy of OrbTorrent is missing the licence file."
        return [note, licence].compactMap(\.self).joined(separator: "\n\n")
    }
}

// MARK: - Privacy

/// What OrbTorrent connects to, and that it collects nothing.
struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                TorrentIcon(symbol: "hand.raised.fill", size: 40)
                Text("Privacy")
                    .font(.title2.weight(.bold))
            }
            Text("OrbTorrent collects nothing about you. There's no account, no analytics and no crash reporting, and your library, settings and extension passwords stay on this Mac.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 12) {
                Text("It connects only to:")
                    .font(.headline)
                point("person.2", "Peers and trackers",
                      "for the downloads you add, as every torrent app does. They can see your IP address, unless you download through a VPN.")
                point("list.bullet", "raw.githubusercontent.com",
                      "for a public list of trackers, while “Find more peers for public torrents” is on.")
                point("link", "Web addresses you add torrents from",
                      "to fetch the .torrent file.")
                point("puzzlepiece.extension", "The sites an extension lists",
                      "while it's on. Each extension's page shows them, and it can't reach any others.")
                point("arrow.triangle.2.circlepath", "updates.orbtorrent.com",
                      "once a day, to check for a new version, while “Check for updates automatically” is on. It sends OrbTorrent's version and build number, which is how we count the Macs on each version. The address a check comes from isn't kept.")
                point("arrow.down.app", "github.com",
                      "to download an update you install.")
            }
            Text("Report a Problem only opens your own mail app with the report filled in. Nothing is sent until you send it.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 20)
            Text("\(Text(title).fontWeight(.semibold)) \(detail)")
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
