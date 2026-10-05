import Foundation

/// What a release name says, such as
/// "Orbit.Station.S02E01.Cold.Start.1080p.WEB.H264-GROUP.mkv":
/// the title, and the season and episode, the date or the year. The rest of
/// the name is details, such as its resolution and source.
///
/// Nil when the name doesn't clearly follow the pattern, such as
/// "ubuntu-26.04-desktop-amd64.iso", so it's shown as it is.
struct ReleaseName: Equatable, Sendable {
    var title: String
    var year: Int?
    /// One, or each of a pack's, such as [1, 2, 3] for "S01-S03".
    var seasons: [Int] = []
    var episodes: [Int] = []
    /// An episode numbered from the show's first, as anime often are, such
    /// as 12 in "Title - 12".
    var absoluteEpisode: Int?
    /// A daily show's date.
    var date: DateComponents?
    /// The words after the episode number, such as "Cold Start".
    var episodeTitle: String?
    /// The picture's resolution and whether it's HDR, as the name gives
    /// them, such as "4K HDR" or "1080p".
    var quality: String?

    init?(_ name: String) {
        var text = name.trimmingCharacters(in: .whitespacesAndNewlines) as NSString

        // A file's extension: one for a video or audio file goes, and any
        // other, such as a disk image's or a program's, isn't a release name.
        let ext = text.pathExtension.lowercased()
        if Self.mediaExtensions.contains(ext) {
            text = text.deletingPathExtension as NSString
        } else if Self.otherExtensions.contains(ext) {
            return nil
        }

        // A group or website before the name: "[Group] Title - 12" or
        // "www.example.org - Title (2026)". A bracket of tags, such as
        // "[h265 - hevc]", isn't a group.
        var hadGroup = false
        while let match = Self.leadingGroup.firstMatch(in: text as String, range: NSRange(location: 0, length: text.length)) {
            let group = text.substring(with: match.range(at: 1))
            if !group.lowercased().contains("www"), !Self.contains(Self.tag, in: group) { hadGroup = true }
            text = text.substring(from: match.range.upperBound) as NSString
        }
        if let match = Self.leadingWebsite.firstMatch(in: text as String, range: NSRange(location: 0, length: text.length)) {
            text = text.substring(from: match.range.upperBound) as NSString
        }
        let string = text as String
        func matches(_ pattern: NSRegularExpression) -> [NSTextCheckingResult] {
            pattern.matches(in: string, range: NSRange(location: 0, length: text.length))
        }
        /// The pattern matched right at `location`, if it does.
        func match(_ pattern: NSRegularExpression, at location: Int) -> NSTextCheckingResult? {
            pattern.firstMatch(in: string, options: .anchored, range: NSRange(location: location, length: text.length - location))
        }
        func number(_ match: NSTextCheckingResult, _ group: Int) -> Int? {
            let range = match.range(at: group)
            return range.location == NSNotFound ? nil : Int(text.substring(with: range))
        }

        // Where the title ends: at the first episode, season, date or
        // quality tag, but never at the very start, where it's the title,
        // as in "1999" or "DUAL".
        var marks: [(range: NSRange, kind: Mark)] = []
        for match in matches(Self.seasonEpisode) { marks.append((match.range, .seasonEpisode(match))) }
        for match in matches(Self.crossEpisode) { marks.append((match.range, .crossEpisode(match))) }
        for match in matches(Self.seasonWord) { marks.append((match.range, .season(match))) }
        for match in matches(Self.seasonPack) { marks.append((match.range, .season(match))) }
        for match in matches(Self.episodeWord) { marks.append((match.range, .episode(match))) }
        for match in matches(Self.date) { marks.append((match.range, .date(match, year: 1, month: 2, day: 3))) }
        for match in matches(Self.usDate) { marks.append((match.range, .date(match, year: 3, month: 1, day: 2))) }
        for match in matches(Self.tag) + matches(Self.upperTag) { marks.append((match.range, .tag)) }
        marks.removeAll { $0.range.location == 0 }
        // One mark inside another, such as "E02" in "S01E02", isn't one of its own.
        let found = marks
        marks.removeAll { mark in
            found.contains { other in
                other.range.length > mark.range.length && NSIntersectionRange(other.range, mark.range).length == mark.range.length
            }
        }
        marks.sort { $0.range.location < $1.range.location }
        let firstMark = marks.first

        // The year, before the first mark: one in brackets if there is one,
        // as in "Orbit 2049 (2017)", or else the last, so
        // "Summer.1984.2020" keeps the first in its title.
        let latest = Calendar(identifier: .gregorian).component(.year, from: .now) + 1
        let years = matches(Self.year).filter { match in
            guard match.range.location > 0, let year = number(match, 1), year <= latest else { return false }
            return match.range.location < (firstMark?.range.location ?? .max)
                && !marks.contains { if case .date = $0.kind { NSIntersectionRange($0.range, match.range).length > 0 } else { false } }
        }
        let yearMatch = years.first { "([".contains(Character(text.substring(with: NSRange(location: $0.range.location, length: 1)))) } ?? years.last

        let titleEnd = min(yearMatch?.range.location ?? .max, firstMark?.range.location ?? .max)
        guard titleEnd != .max else { return nil }
        var title = Self.clean(text.substring(to: titleEnd))
        year = yearMatch.flatMap { number($0, 1) }
        quality = Self.quality(in: string, afterTitle: text.substring(from: titleEnd))

        // The season and episode, or date, wherever they are.
        var consumed = 0
        if let mark = marks.first(where: { if case .tag = $0.kind { false } else { true } }) {
            consumed = mark.range.upperBound
            switch mark.kind {
            case .seasonEpisode(let found):
                seasons = [number(found, 1)].compactMap { $0 }
                episodes = Self.episodeList(first: number(found, 2), rest: text.substring(with: found.range(at: 3)))
            case .crossEpisode(let found):
                seasons = [number(found, 1)].compactMap { $0 }
                episodes = [number(found, 2)].compactMap { $0 }
            case .season(let found):
                if let first = number(found, 1) {
                    let last = number(found, 2) ?? number(found, 3) ?? first
                    seasons = Array(first...max(first, last))
                }
                // "S2 - 07", "S6.Ep5" or "Season 2 Episode 5".
                if seasons.count == 1, let episode = match(Self.nearbyEpisode, at: consumed),
                   let value = number(episode, 1), !(1900...2100).contains(value) {
                    episodes = [value]
                    consumed = episode.range.upperBound
                }
            case .episode(let found):
                absoluteEpisode = number(found, 1)
            case .date(let found, let year, let month, let day):
                date = DateComponents(year: number(found, year), month: number(found, month), day: number(found, day))
            case .tag:
                break
            }
            // More episodes: "S01E02.S01E03", "S01E01+02" or "1x02-03".
            if let season = seasons.first, !episodes.isEmpty {
                while let more = match(Self.moreEpisodes, at: consumed) ?? match(Self.attachedEpisode, at: consumed),
                      number(more, 1).map({ $0 == season }) ?? true,
                      let episode = number(more, 2), episode > episodes.last!, episode - episodes.last! < 100 {
                    episodes.append(episode)
                    consumed = more.range.upperBound
                }
            }
        }
        // After a year: "Show.2014.208" is season 2, episode 8, and
        // "Title (2014) - 39" anime episode 39.
        if seasons.isEmpty, absoluteEpisode == nil, date == nil, let yearMatch {
            if let code = match(Self.episodeCode, at: yearMatch.range.upperBound) {
                seasons = [number(code, 1)].compactMap { $0 }
                episodes = [number(code, 2)].compactMap { $0 }
                consumed = code.range.upperBound
            } else if let episode = match(Self.yearEpisode, at: yearMatch.range.upperBound) {
                absoluteEpisode = number(episode, 1)
                consumed = episode.range.upperBound
            }
        }
        if !episodes.isEmpty || absoluteEpisode != nil {
            let next = marks.first { $0.range.location >= consumed }?.range.location ?? text.length
            let words = Self.clean(text.substring(with: NSRange(location: consumed, length: max(0, next - consumed))))
            if words.contains(where: \.isLetter), words.count <= 80 { episodeTitle = words }
        }

        // Anime: "Title - 12", or "Title 12" after a group.
        if seasons.isEmpty, absoluteEpisode == nil, date == nil, year == nil,
           let found = (hadGroup ? Self.groupAnime : Self.anime).firstMatch(in: title, range: NSRange(location: 0, length: (title as NSString).length)) {
            absoluteEpisode = Int((title as NSString).substring(with: found.range(at: 2)))
            title = Self.clean((title as NSString).substring(with: found.range(at: 1)))
        }

        guard title.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
        // A name that starts with its episode, as in "5x09 - 100", has no title to find.
        guard !Self.contains(Self.seasonEpisode, in: title), !Self.contains(Self.crossEpisode, in: title) else { return nil }
        // A title and quality tags alone aren't enough to go on.
        guard year != nil || !seasons.isEmpty || !episodes.isEmpty || absoluteEpisode != nil || date != nil else { return nil }
        self.title = title
    }

    /// "4K HDR", "1080p" or "HDR", from tags such as "2160p", "UHD",
    /// "1920x1080", "HDR10+" or "DV". Not "HDRip", which isn't HDR. A
    /// resolution such as "1080p" can't be part of a title, but "4K" or "HDR"
    /// could, so they only count after it.
    static func quality(in name: String, afterTitle rest: String) -> String? {
        let range = NSRange(location: 0, length: (name as NSString).length)
        var resolution: String?
        if let match = resolutionTag.firstMatch(in: name, range: range) {
            let height = Int((name as NSString).substring(with: match.range(at: 1)))!
            let scan = (name as NSString).substring(with: match.range(at: 2)).lowercased()
            resolution = height == 2160 ? "4K" : height == 4320 ? "8K" : "\(height)\(scan)"
        } else if let match = frameSize.firstMatch(in: name, range: range) {
            let height = Int((name as NSString).substring(with: match.range(at: 1)))!
            resolution = height == 2160 ? "4K" : height == 4320 ? "8K" : "\(height)p"
        } else if contains(eightK, in: rest) {
            resolution = "8K"
        } else if contains(fourK, in: rest) {
            resolution = "4K"
        }
        let isHDR = contains(hdr, in: rest) || contains(dolbyVision, in: rest)
        let parts = [resolution, isHDR ? "HDR" : nil].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private enum Mark {
        case seasonEpisode(NSTextCheckingResult), crossEpisode(NSTextCheckingResult)
        case season(NSTextCheckingResult), episode(NSTextCheckingResult)
        case date(NSTextCheckingResult, year: Int, month: Int, day: Int)
        case tag
    }

    /// "E02", "-E03", "-03" or "E02E03" after the first episode.
    private static func episodeList(first: Int?, rest: String) -> [Int] {
        guard let first else { return [] }
        // Each after the last, so the 3 in "S12E13-3_Acts_of_God" is the title's.
        var more: [Int] = []
        for number in rest.split(whereSeparator: { !$0.isNumber }).compactMap({ Int($0) }) {
            guard number > (more.last ?? first) else { break }
            more.append(number)
        }
        guard let last = more.last else { return [first] }
        // "E01-E04" is a range; "E01E02E04" lists each.
        if rest.contains("-"), more.count == 1, last - first < 100 { return Array(first...last) }
        return [first] + more
    }

    /// Dots and underscores between words become spaces, except in initials
    /// such as "N.O.V.A", and what's left of brackets and dashes goes.
    static func clean(_ text: String) -> String {
        var text = text.replacingOccurrences(of: "_", with: " ")
        if text.filter({ $0 == "." }).count > text.filter({ $0 == " " }).count {
            var words: [String] = []
            for part in text.split(separator: ".", omittingEmptySubsequences: false).map(String.init) {
                if part.count == 1, part.first!.isLetter, let last = words.last, last.last?.isLetter == true,
                   last.split(separator: ".").allSatisfy({ $0.count == 1 }) {
                    words[words.count - 1] = last + "." + part
                } else {
                    words.append(part)
                }
            }
            text = words.joined(separator: " ")
        }
        text = text.replacingOccurrences(of: #"\(\s*\)|\[\s*\]|\{\s*\}"#, with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        let edges = CharacterSet(charactersIn: " -–—_.,:;+~([{|/")
        text = text.trimmingCharacters(in: edges)
        // An unclosed bracket left at the end, as in "Title (Director's".
        if let open = text.lastIndex(where: { "([{".contains($0) }), !text[open...].contains(where: { ")]}".contains($0) }) {
            text = String(text[..<open]).trimmingCharacters(in: edges)
        }
        return text
    }

    private static func contains(_ pattern: NSRegularExpression, in text: String) -> Bool {
        pattern.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length)) != nil
    }

    private static func regex(_ pattern: String, caseSensitive: Bool = false) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: caseSensitive ? [] : [.caseInsensitive])
    }

    /// Not after or before a letter or digit.
    private static let start = #"(?<![\p{L}\p{N}])"#
    private static let end = #"(?![\p{L}\p{N}])"#

    /// "S01E02", with more as "E03", "-E03", "-03" or "&E03", but not
    /// " - 94", which starts an episode's title.
    private static let seasonEpisode = regex(start + #"S(\d{1,2})[ ._-]?E(\d{1,5})((?:(?:[ ._]?[-&][ ._]?E|[-&]|E)\d{1,4}(?![\dpi]))*)"# + end)
    private static let crossEpisode = regex(start + #"(\d{1,2})x(\d{2,3})"# + end)
    /// Not after a number, as in Turkish "2.Sezon.7.Bolum", where it's season 2.
    private static let seasonWord = regex(start + #"(?<!\d[ .])(?:Season|Saison|Staffel|Temporada|Stagione|Sezon)[ ._-]?(\d{1,2})(?:(?:-|[ ._]to[ ._]|[ ._]?&[ ._]?)(\d{1,2}))?()"# + end)
    private static let seasonPack = regex(start + #"S(\d{1,2})(?:-S?(\d{1,2})|[ ._]?-[ ._]?S(\d{1,2}))?"# + end)
    private static let episodeWord = regex(start + #"(?:(?:Episode|Episodio|Épisode|Folge|Capitulo|Capítulo|Odcinek|Ep)[ ._-]?|E)(\d{1,4})"# + end)
    private static let nearbyEpisode = regex(#"[ ._]*(?:-[ ._]*)?(?:(?:Episode|Episodio|Épisode|Folge|Capitulo|Capítulo|Odcinek|Ep|E)[ ._-]?)?\[?(\d{1,5})(?:v\d)?\]?"# + #"(?![\dpi])"# + end)
    /// Another episode with its own "S01E", "1x" or "E", as in "S01E02.S01E03".
    private static let moreEpisodes = regex(#"[ ._]*(?:[-+&][ ._]*|and[ ._]+)?(?:S(\d{1,2})[ ._-]?E|\d{1,2}x|E)(\d{1,5})"# + #"(?![\dpi])"# + end)
    /// Another episode right after the last, as in "S01E01+02" or "1x02-03".
    private static let attachedEpisode = regex(#"[-+&_]()(\d{1,4})"# + #"(?![\dpi])"# + end)
    /// "Show.2014.208": season 2, episode 8.
    private static let episodeCode = regex(#"[._ ]([1-9])(\d{2})"# + end)
    /// "Title (2014) - 39": an anime episode after the year.
    private static let yearEpisode = regex(#"\s*-\s*(\d{2,4})(?:v\d)?"# + #"(?![\dpi])"# + end)
    private static let date = regex(start + #"((?:19|20)\d\d)[ ._-](0[1-9]|1[0-2])[ ._-](0[1-9]|[12]\d|3[01])"# + end)
    private static let usDate = regex(start + #"(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])-((?:19|20)\d\d)"# + end)
    private static let year = regex(start + #"[(\[]?((?:19|20)\d\d)[)\]]?"# + end)

    /// Tags that are never words in a title.
    private static let tag = regex(start + #"(?:(?:360|480|540|576|720|1080|1440|2160|4320)[pi]|[48]K|UHD|Blu-?Ray|BD-?Rip|BR-?Rip|BD-?Remux|Remux|WEB-?DL|WEB-?Rip|HDTV|PDTV|SDTV|DVD-?Rip|DVD-?Scr|DVD-?R|HD-?Rip|HD-?CAM|HD-?TS|x26[45]|h\.?26[45]|HEVC|XviD|DivX|10-?bit|AAC(?:[ .]?[257]\.[01])?|HDR10(?:\+|Plus)?|DoVi|E-?AC-?3|AC3|DDP?[257]\.?[01]|TrueHD|DTS(?:-HD)?|Atmos|AMZN|ATVP|DSNP|HMAX|PCOK|PMTP)"# + end)
    /// Tags that are words too, so only in capitals.
    private static let upperTag = regex(start + #"(?:WEB|CAM|NF|AVC|HDR|DV|DUAL|MULTi|MULTI|PROPER|REPACK|EXTENDED|UNRATED|REMASTERED|IMAX|LIMITED|iNTERNAL|INTERNAL|DUBBED|SUBBED|COMPLETE|INTEGRALE|FRENCH|TRUEFRENCH|GERMAN|ITALIAN|SPANISH|HINDI|TAMIL|TELUGU|KOREAN|JAPANESE|VOSTFR|NORDiC|SWESUB)"# + end, caseSensitive: true)

    /// "1080p", or "1080p24" with its frame rate.
    private static let resolutionTag = regex(start + #"(360|480|540|576|720|1080|1440|2160|4320)([pi])(?:\d{2,3})?"# + end)
    private static let frameSize = regex(start + #"(?:640|720|854|960|1024|1280|1440|1920|2048|2560|3840|4096|7680)[x×*](360|480|540|576|720|1080|1440|2160|4320)"# + end)
    private static let fourK = regex(start + #"(?:4K|UHD)"# + end)
    private static let eightK = regex(start + #"8K"# + end)
    private static let hdr = regex(start + #"(?:HDR(?:10)?(?:\+|Plus)?|Dolby[ ._-]?Vision|DoVi|HLG)"# + #"(?![\p{L}\p{N}+])"#)
    /// "DV" only in capitals, as a tag.
    private static let dolbyVision = regex(start + #"DV"# + end, caseSensitive: true)

    private static let anime = regex(#"^(.*?\S)\s+-\s+(\d{1,4})(?:v\d)?$"#)
    private static let groupAnime = regex(#"^(.*?\S)\s+(?:-\s+)?(\d{2,4})(?:v\d)?$"#)

    private static let leadingGroup = regex(#"^\s*[\[【]([^\]】]{1,40})[\]】][\s._-]*"#)
    private static let leadingWebsite = regex(#"^(?:www\.[\p{L}\p{N}-]+\.[a-z]{2,10}|[\p{L}\p{N}-]+\.(?:com|org|net|to|cc|me|io|info|tv|ws|se|xyz|club|site|top|cymru|eu|li|is|pw|vip|lol|fun|cyou|bond|link))(?:\.[a-z]{2})?\s*[-–]\s*"#)

    private static let mediaExtensions: Set<String> = [
        "mkv", "mp4", "m4v", "mov", "avi", "wmv", "webm", "ts", "m2ts", "mpg", "mpeg", "flv", "mk3d",
        "mp3", "flac", "m4a", "ogg", "opus", "srt", "ass", "torrent", "nzb",
    ]
    private static let otherExtensions: Set<String> = [
        "iso", "dmg", "img", "bin", "exe", "msi", "pkg", "app", "apk", "deb", "rpm", "zip", "rar", "7z",
        "tar", "gz", "bz2", "xz", "zst", "pdf", "epub", "mobi", "azw3", "cbz", "cbr", "txt", "nfo",
    ]
}
