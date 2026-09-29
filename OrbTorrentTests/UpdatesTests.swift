import Foundation
import Testing
@testable import OrbTorrent

/// What's New: release notes as written on GitHub, and the releases kept from the feed.
@MainActor
final class UpdatesTests {
    @Test func notesBecomeSections() {
        let notes = ReleaseNotesDocument(markdown: """
        <!-- Release notes generated using configuration in .github/release.yml at main -->
        ## New
        - **Automatic updates.** OrbTorrent checks once a day,
          and installs when you're ready.
        - **What's New**: shows what changed.

        ## Fixed
        * The speed limit applies straight away by @someone in https://github.com/sanjevirau/OrbTorrent/pull/12
        ![A screenshot](https://example.com/shot.png)

        ## New Contributors
        * @someone made their first contribution in https://github.com/sanjevirau/OrbTorrent/pull/12

        **Full Changelog**: https://github.com/sanjevirau/OrbTorrent/compare/v1...v2
        """)
        #expect(notes.sections.map(\.title) == ["New", "Fixed"])
        #expect(notes.sections.map(\.kind) == [.new, .fixed])

        let new = notes.sections[0].items
        #expect(new.count == 2)
        #expect(new[0].title.map { String($0.characters) } == "Automatic updates")
        #expect(String(new[0].text.characters) == "OrbTorrent checks once a day, and installs when you're ready.")
        #expect(new[1].title.map { String($0.characters) } == "What's New")
        #expect(String(new[1].text.characters) == "shows what changed.")

        let fixed = notes.sections[1].items
        #expect(fixed.count == 1)
        #expect(fixed[0].title == nil)
        #expect(String(fixed[0].text.characters) == "The speed limit applies straight away")
    }

    @Test func notesWithoutHeadingsAreOneSection() {
        let notes = ReleaseNotesDocument(markdown: "A quieter fix-up release.\n\n- Faster start\n- Smaller download")
        #expect(notes.sections.count == 1)
        #expect(notes.sections[0].title == nil)
        #expect(notes.sections[0].items.map { String($0.text.characters) } == ["A quieter fix-up release.", "Faster start", "Smaller download"])
    }

    @Test func linksStayLinks() {
        let notes = ReleaseNotesDocument(markdown: "- See [the guide](https://orbtorrent.com/guide) for more.")
        let text = notes.sections[0].items[0].text
        #expect(String(text.characters) == "See the guide for more.")
        #expect(text.runs.contains { $0.link == URL(string: "https://orbtorrent.com/guide") })
    }

    @Test func headingsSayWhatKindOfChange() {
        #expect(ReleaseNotesDocument.Kind(heading: "What's Changed") == .new)
        #expect(ReleaseNotesDocument.Kind(heading: "Improvements") == .improved)
        #expect(ReleaseNotesDocument.Kind(heading: "Bug Fixes") == .fixed)
        #expect(ReleaseNotesDocument.Kind(heading: "Known Issues") == .issues)
        #expect(ReleaseNotesDocument.Kind(heading: "Thanks") == .other)
    }

    @Test func historyKeepsNewestAndFindsSkippedReleases() throws {
        let defaults = try #require(UserDefaults(suiteName: "UpdatesTests-\(UUID())"))
        let history = ReleaseHistory(defaults: defaults)
        history.remember((1...12).map { release($0) })
        history.remember([release(3, notes: "Changed")])
        #expect(history.releases.map(\.build) == (1...12).reversed().map(String.init))
        #expect(history.release(build: "3")?.notes == "Changed")
        // Builds compare as numbers: 10 is newer than 9.
        #expect(history.releases(after: "8", upTo: "10").map(\.build) == ["10", "9"])
        #expect(ReleaseHistory(defaults: defaults).releases.count == 12)
    }

    private func release(_ build: Int, notes: String = "Notes") -> Release {
        Release(build: String(build), version: "1.0", title: "1.0 beta \(build)", date: nil, notes: notes, link: nil)
    }
}

/// Report a Problem: everything it sends is shown first, with addresses hidden.
struct ProblemReportTests {
    @Test func logHidesAddressesAndTheUser() {
        let log = """
        (I) 2026-09-29T12:08:15 - Detected external IP. IP: "161.142.139.54"
        (I) 2026-09-29T12:08:15 - Detected external IP. IP: "2001:f40:996:1468:80c:c595:bbf7:3fbf"
        (I) 2026-09-29T12:08:16 - Peer fe80::1 connected, listening on 0.0.0.0:6881
        (I) 2026-09-29T12:08:17 - Saved to \(NSHomeDirectory())/Downloads, libtorrent 1.2.20
        """
        let redacted = ProblemReport.redacted(log)
        #expect(!redacted.contains("161.142.139.54"))
        #expect(!redacted.contains("2001:f40"))
        #expect(!redacted.contains("fe80::1"))
        #expect(!redacted.contains(NSHomeDirectory()))
        #expect(redacted.contains("~/Downloads"))
        // Times and versions stay.
        #expect(redacted.contains("12:08:15"))
        #expect(redacted.contains("1.2.20"))
        #expect(redacted.components(separatedBy: "[IP address]").count - 1 == 4)
    }

    @Test func mailIsAddressedAndFilledIn() throws {
        var report = ProblemReport()
        report.description = "Downloads stop when the Mac sleeps.\nThen they don't resume."
        let url = try #require(report.mailURL())
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.scheme == "mailto")
        #expect(components.path == "help@orbtorrent.com")
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        #expect(items["subject"] == "\(AppIdentity.name): Downloads stop when the Mac sleeps.")
        let body = try #require(items["body"])
        #expect(body.hasPrefix("Downloads stop when the Mac sleeps.\nThen they don't resume."))
        #expect(body.contains("— About this Mac —"))
        #expect(body.contains("macOS "))
        #expect(!body.contains("Engine log"))
    }

    @Test func logIsSentOnlyWhenIncluded() {
        var report = ProblemReport()
        report.description = "It stopped."
        #expect(!report.text(log: "the log").contains("the log"))
        report.includesLog = true
        #expect(report.text(log: "the log").hasSuffix("IP addresses hidden —\nthe log"))
    }
}
