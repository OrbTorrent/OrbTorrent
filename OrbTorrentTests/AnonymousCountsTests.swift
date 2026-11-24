import Foundation
import Testing
@testable import OrbTorrent

/// The anonymous counts the update check carries: what each says, and that
/// each is sent once, as the feed counts it.
@MainActor
struct AnonymousCountsTests {
    private let defaults = UserDefaults(suiteName: "AnonymousCountsTests-\(UUID())")!

    @Test func firstCheckIsCountedOnceAWeekAndMonth() {
        let counts = AnonymousCounts(defaults: defaults)
        let october2 = date("2026-10-02T09:00:00Z")
        let first = counts.valuesForCheck(manual: false, now: october2)
        #expect(value("new", first) == "1")
        #expect(value("week", first) == "1")
        #expect(value("month", first) == "1")

        counts.checkFinished(reachedFeed: true)
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
        counts.checkFinished(reachedFeed: true)
        let next = counts.values(manual: false)
        #expect(value("quits", next) == "0")
        #expect(value("engineStops", next) == "1")
    }

    /// The feed counts a check as it arrives, so one OrbTorrent never hears
    /// back from, because it quit or the answer didn't arrive, isn't sent again.
    @Test func aCheckWithNoAnswerIsStillSentOnce() {
        let counts = AnonymousCounts(defaults: defaults)
        let monday = date("2026-11-23T17:38:00Z")
        counts.appDidLaunch()
        counts.appDidLaunch()
        _ = counts.valuesForCheck(manual: false, now: monday)

        // OrbTorrent quits unexpectedly before the answer, and opens again.
        counts.appDidLaunch()
        let again = counts.valuesForCheck(manual: true, now: date("2026-11-23T18:03:00Z"))
        #expect(value("new", again) == "0")
        #expect(value("week", again) == "0")
        #expect(value("month", again) == "0")
        #expect(value("quits", again) == "1")
    }

    @Test func aCheckThatNeverReachedTheFeedIsSentAgain() {
        let counts = AnonymousCounts(defaults: defaults)
        let october2 = date("2026-10-02T09:00:00Z")
        counts.appDidLaunch()
        counts.appDidLaunch()
        counts.engineStoppedUnexpectedly()
        _ = counts.valuesForCheck(manual: false, now: october2)
        counts.engineStoppedUnexpectedly()
        counts.checkFinished(reachedFeed: false)

        let next = counts.valuesForCheck(manual: false, now: october2)
        #expect(value("new", next) == "1")
        #expect(value("week", next) == "1")
        #expect(value("month", next) == "1")
        #expect(value("quits", next) == "1")
        #expect(value("engineStops", next) == "2")

        // Once it has, only what came after it is left.
        counts.checkFinished(reachedFeed: true)
        counts.checkFinished(reachedFeed: false)
        let after = counts.values(manual: false, now: october2)
        #expect(value("new", after) == "0")
        #expect(value("engineStops", after) == "0")
    }

    /// With "Send anonymous counts" off, checks still say this Mac has
    /// checked, and the quits wait for a check that sends them.
    @Test func checksWithoutCountsKeepTheQuits() {
        let counts = AnonymousCounts(defaults: defaults)
        let october2 = date("2026-10-02T09:00:00Z")
        counts.appDidLaunch()
        counts.appDidLaunch()
        #expect(counts.valuesForCheck(manual: false, sending: false, now: october2).isEmpty)
        counts.checkFinished(reachedFeed: true)

        let next = counts.values(manual: false, now: october2)
        #expect(value("new", next) == "0")
        #expect(value("week", next) == "0")
        #expect(value("quits", next) == "1")
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

    /// Sparkle's errors, which wrap the network's, as when the feed can't be downloaded.
    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, true),
        (.cannotFindHost, true),
        (.cannotConnectToHost, true),
        (.timedOut, true),
        (.secureConnectionFailed, true),
        (.networkConnectionLost, false),
        (.cancelled, false),
    ])
    func checksThatNeverReachedTheFeed(code: URLError.Code, neverReached: Bool) {
        let network = NSError(domain: NSURLErrorDomain, code: code.rawValue)
        let download = NSError(domain: "SUSparkleErrorDomain", code: 2001, userInfo: [NSUnderlyingErrorKey: network])
        let check = NSError(domain: "SUSparkleErrorDomain", code: 2001, userInfo: [NSUnderlyingErrorKey: download])
        #expect(Updates.neverReachedFeed(check) == neverReached)
    }

    @Test func errorsAfterTheFeedHadTheCheckReachedIt() {
        // No update, a feed that isn't signed properly, or an HTTP error.
        #expect(!Updates.neverReachedFeed(NSError(domain: "SUSparkleErrorDomain", code: 1001)))
        #expect(!Updates.neverReachedFeed(NSError(domain: "SUSparkleErrorDomain", code: 1000)))
    }

    private func value(_ key: String, _ values: [AnonymousCounts.Value]) -> String? {
        values.first { $0.key == key }?.value
    }

    private func date(_ text: String) -> Date {
        try! Date(text, strategy: .iso8601)
    }
}
