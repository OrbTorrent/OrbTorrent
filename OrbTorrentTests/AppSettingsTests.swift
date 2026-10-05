import Foundation
import Testing
@testable import OrbTorrent

@MainActor
final class AppSettingsTests {
    private let suite = TestDefaults.makeSuiteName()

    deinit {
        TestDefaults.remove(suite)
    }

    @Test func aNewInstallAsksBeforeDownloadingAndDeletesToTheTrash() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)

        #expect(settings.addBehavior == .askFirst)
        #expect(settings.deleteBehavior == .moveToTrash)
    }

    @Test func keepsWhatThePersonChose() {
        let defaults = UserDefaults(suiteName: suite)!
        let settings = AppSettings(defaults: defaults)
        settings.addBehavior = .startImmediately
        settings.deleteBehavior = .deletePermanently

        let reopened = AppSettings(defaults: defaults)
        #expect(reopened.addBehavior == .startImmediately)
        #expect(reopened.deleteBehavior == .deletePermanently)
    }

    @Test func tidiesNamesUntilTurnedOff() {
        let defaults = UserDefaults(suiteName: suite)!
        let settings = AppSettings(defaults: defaults)
        let files = ["Show/Show.Name.S01E01.mkv", "Show/Show.Name.S01E02.mkv"]
        #expect(settings.tidiesNames)
        #expect(settings.shownFileNames(files) == ["S01E01", "S01E02"])

        settings.tidiesNames = false
        #expect(settings.shownFileNames(files) == [nil, nil])
        #expect(AppSettings(defaults: defaults).tidiesNames == false)
    }
}
