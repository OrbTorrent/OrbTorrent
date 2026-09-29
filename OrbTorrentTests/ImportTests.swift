import Foundation
import Testing
@testable import OrbTorrent

/// Bringing downloads and settings over from Transmission and qBittorrent.
final class ImportTests {
    private let folder = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-import-\(UUID().uuidString)")

    init() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: folder)
    }

    // MARK: Helpers

    private typealias FileEntry = (path: [String], length: Int64, isPadding: Bool)

    private func torrentData(_ name: String, files: [FileEntry]? = nil) -> Data {
        var info: [String: BencodeValue] = [
            "name": .text(name), "piece length": .integer(16_384), "pieces": .bytes(Data(repeating: 7, count: 20)),
        ]
        if let files {
            info["files"] = .list(files.map { file in
                var entry: [String: BencodeValue] = ["length": .integer(file.length), "path": .list(file.path.map(BencodeValue.text))]
                if file.isPadding { entry["attr"] = .text("p") }
                return .dict(entry)
            })
        } else {
            info["length"] = .integer(10)
        }
        return BencodeValue.dict(["info": .dict(info)]).encoded
    }

    private func decode(_ data: Data) throws -> BencodeValue {
        var decoder = BencodeDecoder(data: data)
        return try decoder.decode()
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func preferences(_ overrides: [String: Any] = [:]) throws -> EnginePreferences {
        var json: [String: Any] = [
            "save_path": folder.path, "dl_limit": 0, "up_limit": 5_000 * 1_024, "listen_port": 50_000, "upnp": true,
            "dht": true, "pex": true, "lsd": true, "encryption": 0, "bittorrent_protocol": 0,
            "max_connec": 500, "max_connec_per_torrent": 100, "max_ratio_enabled": false, "max_ratio": 2, "max_ratio_act": 0,
        ]
        json.merge(overrides) { $1 }
        return try JSONDecoder().decode(EnginePreferences.self, from: JSONSerialization.data(withJSONObject: json))
    }

    // MARK: Bencode

    @Test func bencodeWritesSortedKeysAndReadsItBack() throws {
        let value = BencodeValue.dict(["b": .integer(-3), "a": .list([.text("x"), .bytes(Data([0, 1]))])])
        #expect(value.encoded == Data("d1:al1:x2:".utf8) + Data([0, 1]) + Data("e1:bi-3ee".utf8))
        let read = try decode(value.encoded)
        #expect(read["b"]?.integer == -3)
        #expect(read["a"]?.list?.first?.string == "x")
    }

    // MARK: Transmission

    @Test func aTransmissionDownloadKeepsItsChoicesNameLabelsLimitsAndHistory() throws {
        let metadata = torrentData("Show", files: [(["a.mkv"], 10, false), ([".pad", "6"], 6, true), (["b.mkv"], 10, false)])
        let hash = try TorrentMetadata(data: metadata).infoHash
        // Transmission added .part to the unfinished file.
        try write("partial", to: folder.appending(path: "Show/a.mkv.part"))
        let resume = BencodeValue.dict([
            "destination": .text(folder.path), "name": .text("My Show"),
            // Transmission leaves out the padding file.
            "dnd": .list([.integer(0), .integer(1)]), "priority": .list([.integer(1), .integer(0)]),
            "files": .list([.text("Show/a.mkv"), .text("Show/Renamed.mkv")]),
            "labels": .list([.text("tv"), .text("a,b")]), "paused": .integer(1),
            "added-date": .integer(100), "done-date": .integer(0), "progress": .dict(["pieces": .text("none")]),
            "uploaded": .integer(7), "downloaded": .integer(9),
            "downloading-time-seconds": .integer(4), "seeding-time-seconds": .integer(3),
            "ratio-limit": .dict(["ratio-mode": .integer(1), "ratio-limit": .text("1.500000")]),
            "idle-limit": .dict(["idle-mode": .integer(2), "idle-limit": .integer(30)]),
            "speed-limit-down": .dict(["speed-Bps": .integer(50_000), "use-speed-limit": .integer(1)]),
            "speed-limit-up": .dict(["speed-Bps": .integer(9_000), "use-speed-limit": .integer(0)]),
        ])

        let download = try #require(TransmissionImporter.download(
            hash: hash, metadata: metadata, magnet: nil, resume: resume, isActive: nil, category: "Blue", defaultFolder: "/tmp"))
        let written = try decode(download.resumeData)

        #expect(download.name == "My Show")
        #expect(written["info-hash"]?.data?.count == 20)
        #expect(written["save_path"]?.string == folder.path)
        #expect(written["qBt-savePath"]?.string == folder.path)
        #expect(written["qBt-downloadPath"]?.string == "")
        #expect(written["file_priority"]?.list?.compactMap(\.integer) == [6, 0, 0])
        #expect(written["mapped_files"]?.list?.compactMap(\.string) == ["", "", "Show/Renamed.mkv"])
        #expect(written["qBt-name"]?.string == "My Show")
        #expect(written["qBt-category"]?.string == "Blue")
        #expect(written["qBt-tags"]?.list?.compactMap(\.string) == ["tv", "a b"])
        #expect(written["qBt-ratioLimit"]?.integer == 1_500)
        #expect(written["qBt-inactiveSeedingTimeLimit"]?.integer == -1)
        #expect(written["download_rate_limit"]?.integer == 50_000)
        #expect(written["upload_rate_limit"] == nil)
        #expect(written["added_time"]?.integer == 100)
        #expect(written["total_uploaded"]?.integer == 7)
        #expect(written["active_time"]?.integer == 7)
        // No progress: the engine checks the files, then stops it as it was.
        #expect(written["pieces"] == nil)
        #expect(written["paused"]?.integer == 0)
        #expect(written["qBt-stopCondition"]?.string == "FilesChecked")
        #expect(written["completed_time"] == nil)
        #expect(written["qBt-seedStatus"]?.integer == 0)
        #expect(download.renames == [.init(from: folder.appending(path: "Show/a.mkv.part"), to: folder.appending(path: "Show/a.mkv"))])
    }

    @Test func anUnfinishedDownloadStaysInTransmissionsIncompleteFolder() throws {
        let metadata = torrentData("Film.mkv")
        let hash = try TorrentMetadata(data: metadata).infoHash
        let incomplete = folder.appending(path: "Incomplete"), destination = folder.appending(path: "Done")
        try write("partial", to: incomplete.appending(path: "Film.mkv"))
        let resume = BencodeValue.dict(["destination": .text(destination.path), "incomplete-dir": .text(incomplete.path)])

        let download = try #require(TransmissionImporter.download(
            hash: hash, metadata: metadata, magnet: nil, resume: resume, isActive: true, category: nil, defaultFolder: "/tmp"))
        let written = try decode(download.resumeData)

        // The engine moves it to the save location when it finishes.
        #expect(written["save_path"]?.string == incomplete.path)
        #expect(written["qBt-downloadPath"]?.string == incomplete.path)
        #expect(written["qBt-savePath"]?.string == destination.path)
        #expect(written["qBt-stopCondition"]?.string == "None")
    }

    @Test func readsTransmissionsFolderWithItsGroupsAndMagnetLinks() throws {
        let app = folder.appending(path: "Transmission")
        let metadata = torrentData("Finished.mkv")
        let hash = try TorrentMetadata(data: metadata).infoHash
        for name in ["Torrents", "Resume"] {
            try FileManager.default.createDirectory(at: app.appending(path: name), withIntermediateDirectories: true)
        }
        try metadata.write(to: app.appending(path: "Torrents/\(hash).torrent"))
        try BencodeValue.dict(["destination": .text(folder.path), "done-date": .integer(500),
                               "progress": .dict(["pieces": .text("all")])])
            .encoded.write(to: app.appending(path: "Resume/\(hash).resume"))

        let magnetHash = String(repeating: "ab", count: 20)
        try write("magnet:?xt=urn:btih:\(magnetHash)&dn=Waiting&tr=udp%3A%2F%2Ftracker.example%3A80", to: app.appending(path: "Torrents/\(magnetHash).magnet"))
        try BencodeValue.dict(["destination": .text(folder.path), "paused": .integer(1)])
            .encoded.write(to: app.appending(path: "Resume/\(magnetHash).resume"))

        let transfers = [["TorrentHash": hash.uppercased(), "Active": true, "GroupValue": 4]]
        try PropertyListSerialization.data(fromPropertyList: transfers, format: .binary, options: 0)
            .write(to: app.appending(path: "Transfers.plist"))
        let read = TransmissionImporter.transfers(in: app)
        #expect(read[hash] == .init(isActive: true, group: 4))

        let found = TransmissionImporter.downloads(in: app, transfers: read, groups: [4: .init(name: "Blue")],
                                                   defaultFolder: "/tmp", excluding: [])
        #expect(found.count == 2)
        let finished = try #require(found.first { $0.download.hash == hash })
        #expect(finished.group == "Blue")
        let resume = try decode(finished.download.resumeData)
        #expect(resume["completed_time"]?.integer == 500)
        #expect(resume["qBt-seedStatus"]?.integer == 1)
        #expect(resume["qBt-stopCondition"]?.string == "None")

        let magnet = try #require(found.first { $0.download.hash == magnetHash })
        #expect(magnet.download.metadata == nil)
        #expect(magnet.download.name == "Waiting")
        let magnetResume = try decode(magnet.download.resumeData)
        #expect(magnetResume["paused"]?.integer == 1)
        #expect(magnetResume["trackers"]?.list?.first?.list?.first?.string == "udp://tracker.example:80")

        // Downloads OrbTorrent already has are left out.
        #expect(TransmissionImporter.downloads(in: app, transfers: read, groups: [:], defaultFolder: "/tmp",
                                               excluding: [hash]).map(\.download.hash) == [magnetHash])
    }

    @Test func transmissionSettingsAreOnlyThoseItsUserChose() {
        let defaults: [String: Any] = ["CheckUpload": false, "UploadLimit": 50, "RatioCheck": false, "RatioLimit": 2,
                                       "DownloadLocationConstant": false, "DownloadFolder": "~/Downloads"]
        #expect(TransmissionImporter.settings(from: [:], defaults: defaults) == ImportedSettings())

        // A limit typed in but never turned on isn't a limit.
        let typedIn = TransmissionImporter.settings(from: ["UploadLimit": 5_000], defaults: defaults)
        #expect(typedIn.uploadLimit == 0)
        #expect(typedIn.downloadLimit == nil)

        let chosen = TransmissionImporter.settings(
            from: ["CheckDownload": true, "DownloadLimit": 300, "RatioCheck": true, "BindPort": 51_000,
                   "EncryptionRequire": true, "UTPGlobal": false, "PeersTotal": 150],
            defaults: defaults)
        #expect(chosen.downloadLimit == 307_200)
        #expect(chosen.ratioLimit == 2)
        #expect(chosen.listenPort == 51_000)
        #expect(chosen.encryption == .require)
        #expect(chosen.peerProtocol == .tcp)
        #expect(chosen.maxConnections == 150)
        #expect(chosen.savePath == nil)
    }

    // MARK: qBittorrent

    @Test func readsQBittorrentsSettingsFile() {
        let ini = IniFile(contents: """
            [BitTorrent]
            Session\\Port=44192
            Session\\GlobalUPSpeedLimit=100
            Session\\BTProtocol=TCP
            Session\\GlobalMaxRatio=1.5
            Session\\ShareLimitAction=Remove
            Session\\DefaultSavePath="/Volumes/Media, Films"

            [Network]
            PortForwardingEnabled=false
            """)
        let settings = QBittorrentImporter.settings(from: ini)
        #expect(settings.listenPort == 44_192)
        #expect(settings.uploadLimit == 102_400)
        #expect(settings.downloadLimit == nil)
        #expect(settings.peerProtocol == .tcp)
        #expect(settings.ratioLimit == 1.5)
        #expect(settings.ratioAction == .remove)
        #expect(settings.savePath == "/Volumes/Media, Films")
        #expect(settings.portMapping == false)
        #expect(settings.dht == nil)
    }

    @Test func readsQBittorrentsDownloadsIncludingMagnetLinks() throws {
        let backup = folder.appending(path: "BT_backup")
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        let metadata = torrentData("Album")
        let hash = try TorrentMetadata(data: metadata).infoHash
        try metadata.write(to: backup.appending(path: "\(hash).torrent"))
        try BencodeValue.dict(["qBt-name": .text("")]).encoded.write(to: backup.appending(path: "\(hash).fastresume"))
        let magnetHash = String(repeating: "cd", count: 20)
        try BencodeValue.dict(["name": .text("Waiting")]).encoded.write(to: backup.appending(path: "\(magnetHash).fastresume"))

        let found = QBittorrentImporter.downloads(in: backup, excluding: [])
        #expect(found.map(\.name).sorted() == ["Album", "Waiting"])
        #expect(found.first { $0.hash == magnetHash }?.metadata == nil)
    }

    // MARK: Settings

    @Test func onlySettingsThatDifferAreOffered() throws {
        var imported = ImportedSettings()
        imported.uploadLimit = 5_000 * 1_024
        imported.downloadLimit = 0
        imported.dht = false
        imported.listenPort = 80
        imported.maxConnections = 3
        imported.ratioLimit = -1

        let changes = imported.changes(from: try preferences())
        // The same upload limit, no download limit, and no ratio limit already.
        #expect(changes.map(\.kind) == [.dht, .maxConnections])
        #expect(changes.last?.value == "10")

        imported.ratioLimit = 1.5
        let ratio = try #require(imported.changes(from: try preferences()).first { $0.kind == .ratio })
        #expect(ratio.value == "1.5, then Stop Seeding")
    }

    // MARK: Writing

    @Test func writesDownloadsTheEngineDoesntHaveAndAddsCategories() throws {
        let backup = folder.appending(path: "Engine/BT_backup"), categories = folder.appending(path: "Engine/categories.json")
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        try Data("kept".utf8).write(to: backup.appending(path: "old.fastresume"))
        try Data(#"{"Films": {"save_path": "/Films"}}"#.utf8).write(to: categories)
        let part = folder.appending(path: "Show/a.mkv.part")
        try write("partial", to: part)

        let downloads = [
            ImportedDownload(hash: "old", name: "Old", metadata: nil, resumeData: Data("new".utf8)),
            ImportedDownload(hash: "new", name: "New", metadata: Data("torrent".utf8), resumeData: Data("resume".utf8),
                             renames: [.init(from: part, to: folder.appending(path: "Show/a.mkv"))]),
        ]
        let written = try ImportWriter.write(downloads, categories: [
            ImportedCategory(name: "Films", options: Data(#"{"save_path": "/Other"}"#.utf8)),
            ImportedCategory(name: "TV", options: Data(#"{"save_path": ""}"#.utf8)),
        ], resumeDirectory: backup, categoriesFile: categories)

        #expect(written == 1)
        #expect(try String(contentsOf: backup.appending(path: "old.fastresume"), encoding: .utf8) == "kept")
        #expect(try String(contentsOf: backup.appending(path: "new.fastresume"), encoding: .utf8) == "resume")
        #expect(try String(contentsOf: backup.appending(path: "new.torrent"), encoding: .utf8) == "torrent")
        #expect(FileManager.default.fileExists(atPath: folder.appending(path: "Show/a.mkv").path))
        #expect(!FileManager.default.fileExists(atPath: part.path))
        let list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: categories)) as? [String: [String: Any]])
        #expect(list["Films"]?["save_path"] as? String == "/Films")
        #expect(list["TV"] != nil)
    }

    // MARK: Welcome

    private func setting(_ kind: ImportedSetting.Kind) -> ImportedSetting {
        ImportedSetting(kind: kind, title: "", value: "", preferences: [:])
    }

    @Test func theWelcomeTakesSettingsFromTheAppUsedMostRecently() {
        let offer = ImportOffer([
            ImportFinding(source: .transmission, downloads: 3, settings: [setting(.dht)], lastUsed: .now.addingTimeInterval(-86_400)),
            ImportFinding(source: .qBittorrent, downloads: 2, settings: [setting(.pex), setting(.lsd)], lastUsed: .now),
        ])

        #expect(offer.sources == [.qBittorrent, .transmission])
        #expect(offer.settingsSource == .qBittorrent)
        #expect(offer.leavesSettingsBehind)
        #expect(offer.summary(of: offer.findings[0]) == "2 downloads and 2 settings")
        #expect(offer.summary(of: offer.findings[1]) == "3 downloads")

        let jobs = offer.jobs(for: [.transmission, .qBittorrent])
        #expect(jobs.map(\.source) == [.qBittorrent, .transmission])
        #expect(jobs.map(\.settings.count) == [2, 0])
        #expect(offer.jobs(for: [.transmission]).map(\.settings.count) == [0])
    }

    @Test func anAppWithOnlySettingsIsOfferedOnlyWhenItsSettingsCount() {
        let olderSettings = ImportFinding(source: .qBittorrent, downloads: 0, settings: [setting(.listenPort)],
                                          lastUsed: .now.addingTimeInterval(-60))
        let left = ImportOffer([
            ImportFinding(source: .transmission, downloads: 0, settings: [setting(.dht)], lastUsed: .now), olderSettings,
        ])
        #expect(left.sources == [.transmission])
        #expect(!left.leavesSettingsBehind)

        let offered = ImportOffer([
            ImportFinding(source: .transmission, downloads: 4, settings: [], lastUsed: .now), olderSettings,
        ])
        #expect(offered.sources == [.transmission, .qBittorrent])
        #expect(offered.settingsSource == .qBittorrent)
        #expect(offered.summary(of: offered.findings[1]) == "1 setting")
        #expect(ImportOffer([]).isEmpty)
    }

    // MARK: Finishing

    @Test func onlyARecentFinishCountsAsJustFinished() throws {
        func torrent(completedOn: Date?) throws -> Torrent {
            var json: [String: Any] = ["hash": "a", "name": "A", "state": "stalledUP", "progress": 1]
            if let completedOn { json["completion_on"] = Int(completedOn.timeIntervalSince1970) }
            return try JSONDecoder().decode(Torrent.self, from: JSONSerialization.data(withJSONObject: json))
        }
        #expect(try torrent(completedOn: .now).finishedJustNow())
        #expect(try torrent(completedOn: nil).finishedJustNow())
        #expect(try !torrent(completedOn: .now.addingTimeInterval(-86_400)).finishedJustNow())
    }
}
