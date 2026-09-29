import Foundation

/// Ways to split the download list into sections, like Finder's Group By.
enum TorrentGrouping: String, CaseIterable, Identifiable {
    case none, dateAdded, status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "None"
        case .dateAdded: "Date Added"
        case .status: "Status"
        }
    }

    /// A titled section of the list.
    struct Group: Identifiable {
        let id: String
        let title: String
        let torrents: [Torrent]
    }

    /// Splits sorted downloads into sections, keeping their order within each;
    /// nil when not grouping.
    func groups(of torrents: [Torrent], now: Date = .now, calendar: Calendar = .current) -> [Group]? {
        switch self {
        case .none:
            nil
        case .dateAdded:
            sections(of: torrents) { Self.dateSection(of: $0.addedOn, now: now, calendar: calendar) }
        case .status:
            sections(of: torrents) { Self.statusSection(of: $0.state.activity) }
        }
    }

    private func sections(of torrents: [Torrent], by section: (Torrent) -> (order: Int, title: String)) -> [Group] {
        var buckets: [Int: (title: String, torrents: [Torrent])] = [:]
        for torrent in torrents {
            let (order, title) = section(torrent)
            buckets[order, default: (title, [])].torrents.append(torrent)
        }
        return buckets.keys.sorted().compactMap { order in
            buckets[order].map { Group(id: "\(rawValue)-\(order)", title: $0.title, torrents: $0.torrents) }
        }
    }

    /// Newest first, as Finder does: Today, Yesterday, Previous 7 Days,
    /// Previous 30 Days, then this year's months, then earlier years.
    private static func dateSection(of date: Date?, now: Date, calendar: Calendar) -> (order: Int, title: String) {
        guard let date else { return (Int.max, "Date Unknown") }
        let today = calendar.startOfDay(for: now)
        func daysAgo(_ days: Int) -> Date { calendar.date(byAdding: .day, value: -days, to: today) ?? today }

        if date >= today { return (0, "Today") }
        if date >= daysAgo(1) { return (1, "Yesterday") }
        if date >= daysAgo(7) { return (2, "Previous 7 Days") }
        if date >= daysAgo(30) { return (3, "Previous 30 Days") }

        let year = calendar.component(.year, from: date)
        let thisYear = calendar.component(.year, from: now)
        if year == thisYear {
            let month = calendar.component(.month, from: date)
            return (100 + 12 - month, calendar.standaloneMonthSymbols[month - 1])
        }
        return (1_000 + thisYear - year, String(year))
    }

    /// What needs attention first, what's finished last.
    private static func statusSection(of activity: TorrentState.Activity) -> (order: Int, title: String) {
        switch activity {
        case .downloading: (0, "Downloading")
        case .stalled, .queued, .checking, .fetchingMetadata, .moving: (1, "Waiting")
        case .stopped: (2, "Paused")
        case .error: (3, "Needs Attention")
        case .seeding: (4, "Seeding")
        case .completed: (5, "Completed")
        }
    }
}
