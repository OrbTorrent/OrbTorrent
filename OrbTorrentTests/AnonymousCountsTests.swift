import Foundation
import Testing
@testable import OrbTorrent

/// The anonymous counts the update check carries: what each says, and that
/// they start over once a check has reached the feed.
@MainActor
struct AnonymousCountsTests {
    private let defaults = UserDefaults(suiteName: "AnonymousCountsTests-\(UUID())")!

    @Test func firstCheckIsCountedOnceAWeekAndMonth() {
        let counts = AnonymousCounts(defaults: defaults)
        let october2 = date("2026-10-02T09:00:00Z")
        #expect(value("new", counts.values(manual: false, now: october2)) == "1")
        #expect(value("week", counts.values(manual: false, now: october2)) == "1")
        #expect(value("month", counts.values(manual: false, now: october2)) == "1")

        counts.checkSucceeded(now: october2)
        let later = counts.values(manual: false, now: date("2026-10-04T23:00:00Z"))
        #expect(value("new", later) == "0")
        #expect(value("week", later) == "0")
        #expect(value("month", later) == "0")

        // Monday starts a new week; the month carries on.
        let monday = counts.values(manual: false, now: date("2026-10-05T00:30:00Z"))
        #expect(value("week", monday) == "1")
        #expect(value("month", monday) == "0")
    }

    @Test func aLaunchAfterOneThatNeverQuitIsAnUnexpectedQuit() {
        let counts = AnonymousCounts(defaults: defaults)
        counts.appDidLaunch()
        counts.appWillQuit()
        counts.appDidLaunch()
        #expect(value("quits", counts.values(manual: false)) == "0")
        // It never quit: the next launch counts it.
        counts.appDidLaunch()
        counts.engineStoppedUnexpectedly()
        let values = counts.valuesForCheck(manual: false)
        #expect(value("quits", values) == "1")
        #expect(value("engineStops", values) == "1")

        // One more while the check is under way waits for the next check.
        counts.engineStoppedUnexpectedly()
        counts.checkSucceeded()
        let next = counts.values(manual: false)
        #expect(value("quits", next) == "0")
        #expect(value("engineStops", next) == "1")
    }

    @Test func onlyTheseAreSent() {
        let values = AnonymousCounts(defaults: defaults).values(manual: true)
        #expect(values.map(\.key) == ["check", "macos", "chip", "installed", "new", "week", "month", "quits", "engineStops"])
        #expect(value("check", values) == "manual")
        #expect(values.allSatisfy { !$0.value.isEmpty && !$0.value.contains(" ") && !$0.value.contains("+") })
    }

    @Test func weeksAreISOWeeksInUTC() {
        #expect(AnonymousCounts.week(of: date("2026-10-02T09:00:00Z")) == "2026-W40")
        // 1 January 2027 is a Friday, in the last week of 2026.
        #expect(AnonymousCounts.week(of: date("2027-01-01T12:00:00Z")) == "2026-W53")
        #expect(AnonymousCounts.month(of: date("2026-10-31T23:59:00Z")) == "2026-10")
    }

    private func value(_ key: String, _ values: [AnonymousCounts.Value]) -> String? {
        values.first { $0.key == key }?.value
    }

    private func date(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }
}
