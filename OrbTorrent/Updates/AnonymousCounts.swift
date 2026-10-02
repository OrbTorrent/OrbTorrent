import Foundation

/// What OrbTorrent counts, anonymously, with its daily update check: values
/// added to the feed's address, which the feed's Worker (`updates/`) adds up.
/// None of them identifies a Mac or a person, and none is about a download or
/// how OrbTorrent is used.
///
/// With every check, unless "Send anonymous counts" is off: the version of
/// macOS, the kind of Mac, the week OrbTorrent was installed, whether this is
/// its first check ever, this week or this month, which is how Macs are
/// counted without an ID, and how often OrbTorrent or its engine quit
/// unexpectedly since the last check.
///
/// Settings' "See What's Sent", About › Privacy and the website's privacy page
/// say the same. Change them together.
@MainActor
final class AnonymousCounts {
    struct Value: Identifiable, Equatable {
        let key: String
        let value: String
        var id: String { key }
    }

    private let defaults: UserDefaults
    /// The counts in the check under way, taken off once it's done.
    private var sent: (quits: Int, engineStops: Int)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.installed) == nil {
            defaults.set(Date.now, forKey: Keys.installed)
        }
    }

    // MARK: Counting

    /// Called once OrbTorrent has launched. A launch that finds the last one
    /// never quit counts as an unexpected quit: a crash, a force quit or the
    /// Mac losing power.
    func appDidLaunch() {
        if defaults.bool(forKey: Keys.running) { increment(Keys.quits) }
        defaults.set(true, forKey: Keys.running)
    }

    /// Called as OrbTorrent quits cleanly.
    func appWillQuit() {
        defaults.set(false, forKey: Keys.running)
    }

    func engineStoppedUnexpectedly() {
        increment(Keys.engineStops)
    }

    // MARK: The check

    /// The values for an update check about to be made, which
    /// `checkSucceeded()` then counts as sent.
    func valuesForCheck(manual: Bool) -> [Value] {
        sent = (defaults.integer(forKey: Keys.quits), defaults.integer(forKey: Keys.engineStops))
        return values(manual: manual)
    }

    /// The values an update check would send.
    func values(manual: Bool, now: Date = .now) -> [Value] {
        let quits = defaults.integer(forKey: Keys.quits)
        let engineStops = defaults.integer(forKey: Keys.engineStops)
        let installed = defaults.object(forKey: Keys.installed) as? Date ?? now
        return [
            Value(key: "check", value: manual ? "manual" : "daily"),
            Value(key: "macos", value: Self.macOSVersion),
            Value(key: "chip", value: Self.chip),
            Value(key: "installed", value: Self.week(of: installed)),
            Value(key: "new", value: flag(!defaults.bool(forKey: Keys.checked))),
            Value(key: "week", value: flag(defaults.string(forKey: Keys.week) != Self.week(of: now))),
            Value(key: "month", value: flag(defaults.string(forKey: Keys.month) != Self.month(of: now))),
            Value(key: "quits", value: String(min(quits, 99))),
            Value(key: "engineStops", value: String(min(engineStops, 99))),
        ]
    }

    /// Once a check has reached the feed: what it counted starts over.
    func checkSucceeded(now: Date = .now) {
        defaults.set(true, forKey: Keys.checked)
        defaults.set(Self.week(of: now), forKey: Keys.week)
        defaults.set(Self.month(of: now), forKey: Keys.month)
        if let sent {
            // Anything counted while the check was under way waits for the next.
            decrement(Keys.quits, by: sent.quits)
            decrement(Keys.engineStops, by: sent.engineStops)
        }
        sent = nil
    }

    // MARK: Values

    /// The macOS version, such as "26.1".
    static var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion)"
    }

    /// "apple" or "intel": the Mac's chip, even while OrbTorrent runs under Rosetta.
    static var chip: String {
        var isArm: Int32 = 0
        var size = MemoryLayout<Int32>.size
        return sysctlbyname("hw.optional.arm64", &isArm, &size, nil, 0) == 0 && isArm == 1 ? "apple" : "intel"
    }

    /// The ISO week a date is in, in UTC, such as "2026-W40". Weeks start on
    /// Monday, so this agrees with the feed's count of each week's Macs.
    static func week(of date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .gmt
        let parts = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d", parts.yearForWeekOfYear ?? 0, parts.weekOfYear ?? 0)
    }

    /// The month a date is in, in UTC, such as "2026-10".
    static func month(of date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let parts = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    private func flag(_ isOn: Bool) -> String { isOn ? "1" : "0" }

    private func increment(_ key: String) {
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
    }

    private func decrement(_ key: String, by amount: Int) {
        defaults.set(max(0, defaults.integer(forKey: key) - amount), forKey: key)
    }

    private enum Keys {
        static let installed = "countsInstalled"
        static let checked = "countsChecked"
        static let week = "countsWeek"
        static let month = "countsMonth"
        static let running = "countsRunning"
        static let quits = "countsQuits"
        static let engineStops = "countsEngineStops"
    }
}

extension AnonymousCounts.Value {
    /// The value as "See What's Sent" shows it, beside the address it's sent in.
    var shown: String {
        switch (key, value) {
        case ("new", "1"), ("week", "1"), ("month", "1"): "Yes"
        case ("new", "0"), ("week", "0"), ("month", "0"): "No"
        case ("check", _): value == "manual" ? "You asked" : "Daily"
        case ("chip", _): value == "apple" ? "Apple silicon" : "Intel"
        default: value
        }
    }

    /// What the value says, in words, for "See What's Sent".
    var meaning: String {
        switch key {
        case "check": "Whether this is the daily check, or one you asked for"
        case "macos": "Your version of macOS"
        case "chip": "Whether your Mac has Apple silicon or Intel"
        case "installed": "The week OrbTorrent was installed"
        case "new": "Whether this is OrbTorrent's first check ever"
        case "week": "Whether it's the first check this week"
        case "month": "Whether it's the first check this month"
        case "quits": "Times OrbTorrent quit unexpectedly since the last check"
        case "engineStops": "Times its download engine stopped unexpectedly since then"
        default: key
        }
    }
}
