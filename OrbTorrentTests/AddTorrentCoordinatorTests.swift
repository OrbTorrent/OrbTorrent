import Foundation
import Testing
@testable import OrbTorrent

/// Asking about a torrent before it's added.
@MainActor
final class AddTorrentCoordinatorTests {
    private let suite = TestDefaults.makeSuiteName()

    deinit {
        TestDefaults.remove(suite)
    }

    private let torrent = Data("d4:infod6:lengthi1024e4:name10:Sintel.mkv12:piece lengthi16384e6:pieces20:\(String(repeating: "s", count: 20))ee".utf8)

    /// Cancelling a torrent in the window keeps the checks of the same
    /// torrent the menu bar is asking about.
    @Test func cancellingInTheWindowKeepsTheMenuBarsChecks() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        let defaults = UserDefaults(suiteName: suite)!
        let store = TorrentStore(engine: EngineController(), orders: DownloadOrderManager(defaults: defaults),
                                 trackerList: TrackerList(file: sandbox.root.appending(path: "trackers.txt")),
                                 notifier: CompletionNotifier(), settings: settings)
        let extensions = Extensions(registry: sandbox.registry(), settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        let adder = AddTorrentCoordinator(store: store, settings: settings, extensions: extensions)
        adder.reveal = { _ in }
        adder.showMenuBarConfirmation = {}
        #expect(extensions.hasBeforeStartHooks)

        let file = sandbox.root.appending(path: "Sintel.torrent")
        try torrent.write(to: file)
        adder.open([file], askingIn: .window)
        adder.open([file], askingIn: .menuBar)
        let inWindow = try #require(adder.pending)
        let inMenuBar = try #require(adder.menuBarQueue.first)
        for _ in 0..<400 where adder.asked(inWindow.id)?.checkState != .done || adder.asked(inMenuBar.id)?.checkState != .done {
            try await Task.sleep(for: .milliseconds(25))
        }
        let hash = try #require(inWindow.infoHash)
        #expect(!extensions.checks.records(for: hash).isEmpty)

        adder.cancel(try #require(adder.asked(inWindow.id)))
        #expect(!extensions.checks.records(for: hash).isEmpty)
        // The last one asked about lets them go.
        adder.decline(try #require(adder.asked(inMenuBar.id)))
        #expect(extensions.checks.records(for: hash).isEmpty)
    }

    /// Priorities chosen for its files are the ones the engine is told, as
    /// in the Files tab: a file unticked and ticked again is Normal.
    @Test func filesGetThePrioritiesChosenBeforeAdding() throws {
        let hash = "e4f19cf636409b72571766c2ae89c98fc21a109d"
        let link = try #require(MagnetLink("magnet:?xt=urn:btih:\(hash)&dn=Sintel"))
        var pending = AddTorrentCoordinator.Pending(source: .magnet(link))
        #expect(pending.priorityChanges.isEmpty)

        pending.fetchedMetadata = TorrentMetadata(infoHash: hash, name: "Sintel", files: [
            .init(id: 0, path: "Sintel/Sintel.mkv", size: 400),
            .init(id: 1, path: "Sintel/Sintel.en.srt", size: 10),
            .init(id: 2, path: "Sintel/Sintel.de.srt", size: 10),
            .init(id: 3, path: "Sintel/Extras.mkv", size: 300),
        ])
        #expect(pending.priorityChanges.isEmpty)
        pending.setPriority(.maximum, of: [0])
        pending.setPriority(.high, of: [1, 2])
        pending.setPriority(.skip, of: [3])
        #expect(pending.priorityChanges == [.maximum: [0], .high: [1, 2], .skip: [3]])
        #expect(pending.neededBytes == 420)

        pending.setPriority(.skip, of: [1])
        pending.setPriority(.normal, of: [1])
        #expect(pending.priority(of: 1) == .normal)
        // Choosing a priority for an unticked file ticks it.
        pending.setPriority(.high, of: [3])
        #expect(pending.priorityChanges == [.maximum: [0], .high: [2, 3]])
    }
}
