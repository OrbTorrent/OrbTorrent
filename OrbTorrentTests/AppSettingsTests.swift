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
}
