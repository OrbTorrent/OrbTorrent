import Foundation
import Testing
@testable import OrbTorrent

@MainActor
final class ExtraTrackersTests {
    private let suite = TestDefaults.makeSuiteName()
    private let a = "udp://tracker.opentrackr.org:1337/announce"
    private let b = "udp://open.stealth.si:80/announce"
    private let c = "http://tracker.dler.org:6969/announce"
    private let d = "udp://explodie.org:6969/announce"
    private let passkey = "https://tracker.example.org/0123456789abcdef0123456789abcdef/announce"

    deinit {
        TestDefaults.remove(suite)
    }

    private func makeTrackers() -> ExtraTrackers {
        ExtraTrackers(defaults: UserDefaults(suiteName: suite)!)
    }

    /// A torrent shaped like qBittorrent 5.2's `torrents/info`, which lists its trackers in its magnet link.
    private func torrent(trackers: [String], hasMetadata: Bool = true, isPrivate: Bool? = false,
                         progress: Double = 0.5) -> Torrent {
        let link = "magnet:?xt=urn:btih:e4f19cf636409b72571766c2ae89c98fc21a109d"
            + trackers.map { "&tr=" + $0.addingPercentEncoding(withAllowedCharacters: .alphanumerics)! }.joined()
        var json: [String: Any] = [
            "hash": "e4f19cf636409b72571766c2ae89c98fc21a109d", "name": "Show", "state": "downloading",
            "progress": progress, "magnet_uri": link, "has_metadata": hasMetadata,
        ]
        json["private"] = isPrivate.map { $0 as Any } ?? NSNull()
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(Torrent.self, from: data)
    }

    // MARK: The list

    @Test func readsTheDailyListAndLeavesOutAnythingUnsafe() {
        let text = """
        \(a)

        \(b)

        \(a)

        # a comment
        udp://localhost:6969/announce

        http://192.168.1.1:80/announce

        udp://10.0.0.8:6969/announce

        \(passkey)

        https://tracker.example.org/announce.php?passkey=abc

        wss://tracker.webtorrent.dev

        http://tracker.renfei.net:8080/announce

        """
        #expect(TrackerList.parse(text) == [a, b, "http://tracker.renfei.net:8080/announce"])
    }

    @Test func aPrivateTrackersAddressDoesntLookPublic() {
        #expect(TrackerList.isPublic(a))
        #expect(TrackerList.isPublic("http://93.184.216.34:80/announce"))
        #expect(!TrackerList.isPublic(passkey))
        #expect(!TrackerList.isPublic("https://tracker.example.org/announce?pk=0123456789abcdef"))
        #expect(!TrackerList.isPublic("http://user:secret@tracker.example.org/announce"))
        #expect(!TrackerList.isPublic("http://tracker.example.local/announce"))
    }

    @Test func usesTheLastListItDownloaded() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-trackers-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: file) }
        let fresh = TrackerList(file: file)
        #expect(fresh.trackers == TrackerList.builtIn)
        #expect(fresh.updated == nil)

        try "\(a)\n\(d)\n".write(to: file, atomically: true, encoding: .utf8)
        let saved = TrackerList(file: file)
        #expect(saved.trackers == [a, d])
        #expect(saved.updated != nil)
    }

    @Test func aMagnetLinkGetsTheListsTrackersAfterItsOwn() throws {
        let link = try #require(MagnetLink("magnet:?xt=urn:btih:e4f19cf636409b72571766c2ae89c98fc21a109d&tr=\(a.addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)"))
        #expect(link.trackers == [a])
        let looked = try #require(MagnetLink(link.adding(trackers: [a, b, c])))
        #expect(looked.trackers == [a, b, c])
        #expect(looked.infoHash == link.infoHash)
    }

    // MARK: Adding them

    @Test func aPublicTorrentGetsTheTrackersItDoesntHave() {
        let trackers = makeTrackers()
        let public1 = torrent(trackers: [a])
        let changes = trackers.changes(for: [public1], list: [a, b, c], revision: 1, enabled: true)
        #expect(changes.map(\.add) == [[b, c]])
        #expect(changes.map(\.remove) == [[]])

        trackers.didApply(changes[0])
        #expect(trackers.added[public1.hash] == [b, c])
        #expect(trackers.changes(for: [torrent(trackers: [a, b, c])], list: [a, b, c], revision: 1, enabled: true).isEmpty)
    }

    @Test func aPrivateTorrentNeverGetsThem() {
        let trackers = makeTrackers()
        #expect(trackers.changes(for: [torrent(trackers: [passkey], isPrivate: true)], list: [a, b], revision: 1, enabled: true).isEmpty)
        // Even one whose tracker looks public.
        #expect(trackers.changes(for: [torrent(trackers: [c], isPrivate: true)], list: [a, b], revision: 1, enabled: true).isEmpty)
    }

    @Test func aMagnetLinkWithAPersonalKeyWaitsUntilItsFilesAreKnown() {
        let trackers = makeTrackers()
        let waiting = torrent(trackers: [passkey], hasMetadata: false, isPrivate: nil)
        #expect(trackers.changes(for: [waiting], list: [a, b], revision: 1, enabled: true).isEmpty)

        let known = torrent(trackers: [passkey], hasMetadata: true, isPrivate: false)
        #expect(trackers.changes(for: [known], list: [a, b], revision: 1, enabled: true).map(\.add) == [[a, b]])
    }

    @Test func aMagnetLinkWithPlainTrackersOrNoneGetsThemStraightAway() {
        let plain = torrent(trackers: [c], hasMetadata: false, isPrivate: nil)
        #expect(makeTrackers().changes(for: [plain], list: [a, b], revision: 1, enabled: true).map(\.add) == [[a, b]])

        let trackerless = torrent(trackers: [], hasMetadata: false, isPrivate: nil)
        #expect(makeTrackers().changes(for: [trackerless], list: [a, b], revision: 1, enabled: true).map(\.add) == [[a, b]])
    }

    @Test func theyComeOffAMagnetLinkThatTurnsOutPrivate() {
        let trackers = makeTrackers()
        let magnet = torrent(trackers: [c], hasMetadata: false, isPrivate: nil)
        trackers.didApply(trackers.changes(for: [magnet], list: [a, b], revision: 1, enabled: true)[0])

        let turnedPrivate = torrent(trackers: [c, a, b], hasMetadata: true, isPrivate: true)
        let changes = trackers.changes(for: [turnedPrivate], list: [a, b], revision: 1, enabled: true)
        #expect(changes.map { Set($0.remove) } == [[a, b]])
        #expect(changes.map(\.add) == [[]])
        trackers.didApply(changes[0])
        #expect(trackers.added[turnedPrivate.hash] == nil)
    }

    @Test func trackersThatDropOffTheListComeOff() {
        let trackers = makeTrackers()
        trackers.didApply(trackers.changes(for: [torrent(trackers: [a])], list: [a, b, c], revision: 1, enabled: true)[0])

        let changes = trackers.changes(for: [torrent(trackers: [a, b, c])], list: [a, c, d], revision: 2, enabled: true)
        #expect(changes.map(\.remove) == [[b]])
        #expect(changes.map(\.add) == [[d]])
    }

    @Test func turningItOffTakesThemOffEvenFinishedTorrents() {
        let trackers = makeTrackers()
        trackers.didApply(trackers.changes(for: [torrent(trackers: [a])], list: [a, b], revision: 1, enabled: true)[0])

        let finished = torrent(trackers: [a, b], progress: 1)
        #expect(trackers.changes(for: [finished], list: [a, b], revision: 1, enabled: false).map(\.remove) == [[b]])
    }

    @Test func aFinishedTorrentDoesntGetThem() {
        #expect(makeTrackers().changes(for: [torrent(trackers: [a], progress: 1)], list: [a, b], revision: 1, enabled: true).isEmpty)
    }

    @Test func oneTakenOffByHandStaysOff() {
        let trackers = makeTrackers()
        trackers.didApply(trackers.changes(for: [torrent(trackers: [a])], list: [a, b, c], revision: 1, enabled: true)[0])

        // c was removed from the torrent; a new list comes out.
        let changes = trackers.changes(for: [torrent(trackers: [a, b])], list: [a, b, c, d], revision: 2, enabled: true)
        #expect(changes.map(\.add) == [[d]])
    }

    @Test func trackersAddedToLookUpAMagnetLinkCountAsOurs() {
        let trackers = makeTrackers()
        let added = torrent(trackers: [a, b, c], hasMetadata: true, isPrivate: false)
        trackers.claim([b, c, d], for: added.hash)
        // d didn't make it onto the torrent, so it's added like any other.
        let changes = trackers.changes(for: [added], list: [b, c, d], revision: 1, enabled: true)
        #expect(changes.map(\.add) == [[d]])
        trackers.didApply(changes[0])
        #expect(trackers.added[added.hash] == [b, c, d])

        let off = trackers.changes(for: [torrent(trackers: [a, b, c, d])], list: [b, c, d], revision: 1, enabled: false)
        #expect(off.map { Set($0.remove) } == [[b, c, d]])
    }

    @Test func remembersWhatItAddedAcrossLaunches() {
        let trackers = makeTrackers()
        trackers.didApply(trackers.changes(for: [torrent(trackers: [a])], list: [a, b], revision: 1, enabled: true)[0])
        #expect(makeTrackers().added == trackers.added)
    }

    @Test func knowsWhetherATorrentIsPrivate() {
        let known = torrent(trackers: [a], hasMetadata: true, isPrivate: true)
        #expect(known.isPrivate == true)
        #expect(known.trackerURLs == [a])
        let magnet = torrent(trackers: [], hasMetadata: false, isPrivate: nil)
        #expect(magnet.isPrivate == nil)
        #expect(!magnet.hasMetadata)
    }
}
