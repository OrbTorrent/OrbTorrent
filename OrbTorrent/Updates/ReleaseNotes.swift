import Foundation

/// One version of OrbTorrent and its notes, as written on its GitHub release
/// and carried in the update feed.
struct Release: Codable, Equatable, Identifiable {
    /// `CFBundleVersion`, the build number updates are compared by.
    let build: String
    /// `CFBundleShortVersionString`, such as "1.0".
    let version: String
    /// The release's name, such as "1.0 beta 2".
    let title: String?
    let date: Date?
    /// Markdown.
    let notes: String
    /// The release's page on GitHub.
    let link: URL?

    var id: String { build }

    /// Such as "1.0 beta 2", or "1.0 (2)" for a release without a name.
    var name: String { title ?? "\(version) (\(build))" }

    static func isNewer(_ build: String, than other: String) -> Bool {
        build.compare(other, options: .numeric) == .orderedDescending
    }
}

/// The notes of recent releases, kept from the update feed each time it's
/// read, so What's New can show them after an update without going online.
@MainActor
final class ReleaseHistory {
    private let defaults: UserDefaults
    private static let key = "releaseHistory"
    /// Enough to cover skipping several updates.
    private static let kept = 20

    private(set) var releases: [Release]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        releases = defaults.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode([Release].self, from: $0) } ?? []
    }

    /// Adds or replaces releases, keeping the newest.
    func remember(_ new: [Release]) {
        var byBuild = Dictionary(releases.map { ($0.build, $0) }, uniquingKeysWith: { $1 })
        for release in new { byBuild[release.build] = release }
        releases = byBuild.values
            .sorted { Release.isNewer($0.build, than: $1.build) }
            .prefix(Self.kept)
            .map(\.self)
        defaults.set(try? JSONEncoder().encode(releases), forKey: Self.key)
    }

    func release(build: String) -> Release? {
        releases.first { $0.build == build }
    }

    /// Releases after `build`, up to and including `current`, newest first.
    func releases(after build: String, upTo current: String) -> [Release] {
        releases.filter { Release.isNewer($0.build, than: build) && !Release.isNewer($0.build, than: current) }
    }
}

/// Release notes in Markdown, as GitHub releases are written, read into
/// sections for What's New. It follows headings, lists and paragraphs, with
/// bold, italics, code and links; images and HTML are left out, and so are
/// the lines GitHub adds to generated notes that only matter on GitHub.
struct ReleaseNotesDocument {
    struct Section: Identifiable {
        let id: Int
        /// The heading above it, if any.
        let title: String?
        var items: [Item] = []

        var kind: Kind { Kind(heading: title) }
    }

    /// What a section is about, from its heading.
    enum Kind {
        case new, improved, fixed, issues, other

        init(heading: String?) {
            let heading = heading?.lowercased() ?? ""
            if heading.isEmpty || ["new", "add", "feature", "what's changed", "highlight"].contains(where: heading.contains) {
                self = .new
            } else if ["fix", "bug"].contains(where: heading.contains) {
                self = .fixed
            } else if ["improv", "better", "change", "enhanc", "faster"].contains(where: heading.contains) {
                self = .improved
            } else if ["known", "issue", "note"].contains(where: heading.contains) {
                self = .issues
            } else {
                self = .other
            }
        }
    }

    struct Item: Identifiable {
        let id: Int
        /// A list item's opening words in bold, such as "Automatic updates"
        /// in "**Automatic updates.** OrbTorrent keeps itself up to date."
        let title: AttributedString?
        let text: AttributedString
    }

    let sections: [Section]

    init(markdown: String) {
        var sections: [Section] = []
        var paragraph: [String] = []
        var listItem: [String]?
        var isSkipping = false
        var nextID = 0

        func add(_ lines: [String]) {
            let text = lines.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty, !isSkipping else { return }
            if sections.isEmpty { sections.append(Section(id: 0, title: nil)) }
            nextID += 1
            sections[sections.count - 1].items.append(Self.item(from: text, id: nextID))
        }
        func flush() {
            if let item = listItem { add(item) }
            add(paragraph)
            listItem = nil
            paragraph = []
        }

        for rawLine in Self.cleaned(markdown).components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if let heading = line.wholeMatch(of: #/#{1,6}\s+(.+?)(?:\s+#+)?/#)?.1 {
                flush()
                let title = String(heading)
                // Thanks to first-time contributors belong on GitHub.
                isSkipping = title.lowercased().contains("contributor")
                guard !isSkipping else { continue }
                nextID += 1
                sections.append(Section(id: nextID, title: Self.plain(title)))
            } else if let item = line.wholeMatch(of: #/(?:[-*+]|\d{1,3}[.)])\s+(.+)/#)?.1 {
                flush()
                listItem = [String(item)]
            } else if listItem != nil {
                listItem?.append(line)
            } else {
                paragraph.append(line)
            }
        }
        flush()
        self.sections = sections.filter { !$0.items.isEmpty }
    }

    /// Without HTML comments, images, "Full Changelog" links, and the
    /// "by @name in <pull request>" GitHub adds to generated notes.
    private static func cleaned(_ markdown: String) -> String {
        markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacing(/<!--[\s\S]*?-->/, with: "")
            .replacing(/!\[[^\]]*\]\([^)]*\)/, with: "")
            .replacing(/<img[^>]*>/, with: "")
            .replacing(/^\s*\*\*Full Changelog\*\*.*$/.anchorsMatchLineEndings(), with: "")
            .replacing(#/\s+by @[\w-]+ in https://github\.com/\S+$/#.anchorsMatchLineEndings(), with: "")
    }

    /// Splits off the bold words an item opens with, if any.
    private static func item(from text: String, id: Int) -> Item {
        if let match = text.wholeMatch(of: /\*\*(.+?)\*\*\s*[:—–-]?\s*(.*)/) {
            let lead = match.1.trimmingCharacters(in: CharacterSet(charactersIn: ".:").union(.whitespaces))
            let rest = String(match.2)
            if !rest.isEmpty {
                return Item(id: id, title: inline(lead), text: inline(rest))
            }
        }
        return Item(id: id, title: nil, text: inline(text))
    }

    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }

    private static func plain(_ text: String) -> String {
        String(inline(text).characters)
    }
}
