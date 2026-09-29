import Foundation
import Observation

/// Public trackers that are working right now, from a list tested and
/// published every day, for finding more peers for public torrents.
///
/// The list is downloaded once a day while the setting is on, and the last
/// good copy is kept. OrbTorrent ships with a copy, for its first launch and
/// for when the list can't be reached.
@MainActor
@Observable
final class TrackerList {
    /// ngosang/trackerslist's "best" list: the most popular public trackers
    /// that answered its daily test.
    nonisolated static let source = URL(string: "https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_best.txt")!

    private(set) var trackers: [String]
    /// When the list was last downloaded; nil while using the copy OrbTorrent ships with.
    private(set) var updated: Date?
    /// Goes up each time the trackers change.
    private(set) var revision = 0

    @ObservationIgnored private let file: URL
    @ObservationIgnored private var lastAttempt: Date?
    @ObservationIgnored private var updateTask: Task<Void, Never>?

    private static let maxAge: TimeInterval = 24 * 60 * 60
    private static let retryAfter: TimeInterval = 60 * 60
    /// More trackers than this mean more announcing for little gain.
    nonisolated static let limit = 30

    init(file: URL = EnginePaths.support.appending(path: "trackers.txt")) {
        self.file = file
        let saved = (try? String(contentsOf: file, encoding: .utf8)).map(Self.parse) ?? []
        if saved.isEmpty {
            trackers = Self.builtIn
        } else {
            trackers = saved
            updated = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        }
    }

    /// Keeps the list up to date while `isEnabled` says the setting is on.
    func start(isEnabled: @escaping @MainActor () -> Bool) {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                if isEnabled() { await self?.updateIfNeeded() }
                // A continuous clock, so this still fires promptly after the Mac sleeps.
                try? await Task.sleep(for: .seconds(15 * 60))
            }
        }
    }

    /// Downloads the list if the copy in use is more than a day old, trying
    /// at most once an hour.
    func updateIfNeeded() async {
        let now = Date.now
        if let updated, now.timeIntervalSince(updated) < Self.maxAge { return }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < Self.retryAfter { return }
        lastAttempt = now
        guard let downloaded = await Self.download() else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? downloaded.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
        updated = now
        if downloaded != trackers {
            trackers = downloaded
            revision += 1
        }
    }

    private nonisolated static func download() async -> [String]? {
        var request = URLRequest(url: source, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.setValue("OrbTorrent", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count < 1_000_000,
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        let trackers = parse(text)
        return trackers.isEmpty ? nil : trackers
    }

    /// The usable trackers in a list with one per line, in order, leaving out
    /// anything that isn't a plain public tracker.
    nonisolated static func parse(_ text: String) -> [String] {
        var seen: Set<String> = []
        var trackers: [String] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let url = line.trimmingCharacters(in: .whitespaces)
            guard isPublic(url), seen.insert(url).inserted else { continue }
            trackers.append(url)
            if trackers.count == limit { break }
        }
        return trackers
    }

    /// Whether a tracker is one anyone can use: a plain announce address on
    /// the internet. A private tracker has to know who's announcing, so its
    /// address carries a personal key, in its path or its query.
    nonisolated static func isPublic(_ url: String) -> Bool {
        guard let components = URLComponents(string: url),
              let scheme = components.scheme?.lowercased(), ["udp", "http", "https"].contains(scheme),
              let host = components.host?.lowercased(), !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              ["", "/", "/announce", "/announce.php"].contains(components.path.lowercased())
        else { return false }
        if let port = components.port, !(1...65_535).contains(port) { return false }
        return isInternetHost(host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")))
    }

    /// Leaves out this Mac and the local network, so a bad entry in the list
    /// can't point the engine at a device at home.
    private nonisolated static func isInternetHost(_ host: String) -> Bool {
        if host == "localhost" { return false }
        for suffix in [".localhost", ".local", ".lan", ".home", ".home.arpa", ".internal", ".localdomain"]
        where host.hasSuffix(suffix) {
            return false
        }
        if host.contains(":") {
            // IPv6: only global addresses, 2000::/3.
            return host.first == "2" || host.first == "3"
        }
        let octets = host.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ $0.map { (0...255).contains($0) } ?? false }) else {
            // A name, not an address.
            return !host.allSatisfy { $0.isNumber || $0 == "." }
        }
        let a = octets[0]!, b = octets[1]!
        switch (a, b) {
        case (0, _), (10, _), (127, _), (169, 254), (192, 168): return false
        case (100, 64...127), (172, 16...31): return false
        case (224..., _): return false
        default: return true
        }
    }

    /// The list as of 28 September 2026, for when a newer one hasn't been downloaded.
    static let builtIn = [
        "udp://tracker.opentrackr.org:1337/announce",
        "udp://open.stealth.si:80/announce",
        "udp://open.demonii.com:1337/announce",
        "udp://tracker.skynetcloud.site:6969/announce",
        "udp://tracker.qu.ax:6969/announce",
        "udp://exodus.desync.com:6969/announce",
        "udp://tracker.nyaa.vc:6969/announce",
        "udp://explodie.org:6969/announce",
        "udp://tracker.corpscorp.online:80/announce",
        "udp://tracker.bittor.pw:1337/announce",
        "udp://tracker.ducks.party:1984/announce",
        "udp://tracker-udp.gbitt.info:80/announce",
        "http://tracker2.dler.org:80/announce",
        "http://tracker.dler.org:6969/announce",
        "http://tracker.dler.com:6969/announce",
        "http://tracker.renfei.net:8080/announce",
        "udp://retracker01-msk-virt.corbina.net:80/announce",
        "http://bittorrent-tracker.e-n-c-r-y-p-t.net:1337/announce",
        "udp://t.overflow.biz:6969/announce",
        "udp://tracker.peerfect.org:6969/announce",
    ]
}
