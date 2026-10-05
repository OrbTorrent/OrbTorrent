import Foundation
import Synchronization

/// Names as OrbTorrent shows them while “Show tidy download names” is on: a
/// release name such as "Orbit.Station.S02.1080p.WEB-DL…" as
/// "Orbit Station · Season 2", and a download's files by what tells them
/// apart, such as "S02E01". Anything else shows as it is.
enum ShownNames {
    /// A name as it shows: its text, and its quality for a badge.
    struct Name: Equatable {
        var text: String
        var quality: String?
    }

    /// A download's name, tidied if it's a release name.
    static func download(_ name: String) -> String {
        release(name)?.shownName ?? name
    }

    /// The library's names, by the tidy name each would show, with each
    /// one's quality. Two copies of a film in different qualities are told
    /// apart by their quality; two that would look the same show their names.
    struct Library {
        /// Names and their qualities, by tidy name.
        private var names: [String: [String: String?]] = [:]

        init(_ names: some Sequence<String> = []) {
            for name in names {
                let release = ShownNames.release(name)
                self.names[release?.shownName ?? name, default: [:]][name] = release?.quality
            }
        }

        /// Whether a download other than `name` would show `shown` with the same quality.
        func isShared(_ shown: String, quality: String?, by name: String) -> Bool {
            names[shown, default: [:]].contains { $0.key != name && $0.value == quality }
        }

        /// Whether a download other than `name` would show `shown`, in any quality.
        func hasOther(_ shown: String, by name: String) -> Bool {
            names[shown, default: [:]].keys.contains { $0 != name }
        }
    }

    /// What to show for each file, in the same order, or nil to show its
    /// name as it is.
    ///
    /// Episodes of the show most of them are of show their episode, such as
    /// "S02E01 · Cold Start". Three or more files in a folder whose names
    /// start with the same words, such as "Course.Name.Lecture.01.Intro.mp4",
    /// leave those words out.
    static func files(_ paths: [String]) -> [String?] {
        var shown = [String?](repeating: nil, count: paths.count)
        let names = paths.map { ($0 as NSString).lastPathComponent }

        // Episodes, by video files' titles: the most common one is the show's.
        var episodes: [Int: ReleaseName] = [:]
        for (index, name) in names.enumerated() where FileKind(path: name) == .video {
            if let release = release(name), release.episodeLabel(includingSeasons: false) != nil, release.seasons.count <= 1 {
                episodes[index] = release
            }
        }
        let titles = Dictionary(grouping: episodes.values, by: { key(of: $0.title) })
        if let show = titles.max(by: { $0.value.count < $1.value.count })?.key {
            for (index, release) in episodes where key(of: release.title) == show {
                shown[index] = [release.episodeLabel(includingSeasons: false), release.episodeTitle].compactMap { $0 }.joined(separator: " · ")
            }
        }

        // Shared words at the start, in each folder, for files of a kind.
        let groups = Dictionary(grouping: names.indices.filter { shown[$0] == nil }) { index in
            [(paths[index] as NSString).deletingLastPathComponent, (names[index] as NSString).pathExtension.lowercased()]
        }
        for indices in groups.values where indices.count >= 3 {
            let start = sharedStart(of: indices.map { names[$0] })
            let words = start.split(whereSeparator: { separators.contains($0) }).count
            guard words >= 2, start.count >= 8 else { continue }
            let rests = indices.map { String(names[$0].dropFirst(start.count)) }
            // Each must keep more than its extension.
            guard rests.allSatisfy({ !($0 as NSString).deletingPathExtension.isEmpty }) else { continue }
            for (index, rest) in zip(indices, rests) { shown[index] = rest }
        }

        // Files that would show the same, such as an episode in two
        // qualities, show their qualities, or else their names.
        let alike = Dictionary(grouping: shown.indices.filter { shown[$0] != nil }, by: { shown[$0]! })
        for (label, indices) in alike where indices.count > 1 {
            let qualities = indices.map { release(names[$0])?.quality }
            let apart = Set(qualities.compactMap { $0 }).count == indices.count
            for (index, quality) in zip(indices, qualities) {
                shown[index] = apart ? "\(label) · \(quality!)" : nil
            }
        }
        return shown
    }

    /// The release name a name reads as, remembered, since lists ask for the
    /// same names every second.
    static func release(_ name: String) -> ReleaseName? {
        if let known = remembered.withLock({ $0[name] }) { return known }
        let release = ReleaseName(name)
        remembered.withLock { names in
            if names.count >= 10_000 { names.removeAll() }
            names[name] = release
        }
        return release
    }

    private static let remembered = Mutex<[String: ReleaseName?]>([:])

    private static let separators: Set<Character> = [" ", ".", "_", "-"]

    /// The words every name starts with, up to and including the separator
    /// after the last of them.
    private static func sharedStart(of names: [String]) -> String {
        guard var start = names.first else { return "" }
        for name in names.dropFirst() {
            start = String(zip(start, name).prefix { $0 == $1 }.map(\.0))
        }
        guard start.count < names.map(\.count).min() ?? 0 else { return "" }
        // Back to the end of a whole word.
        while let last = start.last, !separators.contains(last) { start.removeLast() }
        return start
    }

    /// A title as it compares with others: "Orbit.Station" and "Orbit
    /// Station" are the same show.
    private static func key(of title: String) -> String {
        title.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

extension ReleaseName {
    /// "Orbit Station · Season 2", "Sintel (2010)" or "Orbit Station · S02E01".
    var shownName: String {
        [title + (year.map { " (\($0))" } ?? ""), episodeLabel(includingSeasons: true)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// "S02E01", "S01E01–E03", "Episode 12" or "5 Oct 2026", and with
    /// `includingSeasons`, "Season 2" or "Seasons 1–3" for a pack.
    func episodeLabel(includingSeasons: Bool) -> String? {
        func two(_ number: Int) -> String { number < 10 ? "0\(number)" : "\(number)" }
        if let season = seasons.first, let first = episodes.first {
            let last = episodes.last!
            if episodes.count == 1 { return "S\(two(season))E\(two(first))" }
            return episodes == Array(first...last)
                ? "S\(two(season))E\(two(first))–E\(two(last))"
                : "S\(two(season))" + episodes.map { "E\(two($0))" }.joined()
        }
        if let absoluteEpisode { return "Episode \(absoluteEpisode)" }
        if let date, let day = Calendar(identifier: .gregorian).date(from: date) {
            return day.formatted(.dateTime.day().month(.abbreviated).year())
        }
        guard includingSeasons, let first = seasons.first else { return nil }
        return seasons.count == 1 ? "Season \(first)" : "Seasons \(first)–\(seasons.last!)"
    }
}
