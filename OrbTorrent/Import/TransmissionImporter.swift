import AppKit
import Foundation

/// Reads the Transmission app's downloads and settings for importing.
///
/// Transmission keeps each download as a `.torrent`, or a `.magnet` before its
/// details arrive, in `Torrents`, and its state in the `.resume` of the same
/// name in `Resume`. Each becomes the pair of files OrbTorrent's engine keeps,
/// with the download's save location, file choices, name, labels, group,
/// limits and history. Its progress is left out, so the engine checks the
/// files on disk before the download goes on.
enum TransmissionImporter {
    static let bundleIdentifier = "org.m0k.transmission"

    static var folder: URL {
        URL.applicationSupportDirectory.appending(path: "Transmission", directoryHint: .isDirectory)
    }

    /// How the app lists a download: whether it runs, and its group.
    struct Transfer: Sendable, Equatable {
        var isActive: Bool
        var group: Int?
    }

    /// One of the app's groups, which become categories.
    struct Group: Sendable, Equatable {
        let name: String
        var location: String?
    }

    static func plan(excluding existing: Set<String>) -> ImportPlan {
        let preferences = UserDefaults.standard.persistentDomain(forName: bundleIdentifier) ?? [:]
        let defaults = appDefaults
        let groups = groups(from: preferences["GroupDicts"] as? Data)
        let downloadFolder = ((preferences["DownloadFolder"] ?? defaults["DownloadFolder"]) as? String)
            .map { ($0 as NSString).expandingTildeInPath } ?? URL.downloadsDirectory.path

        var plan = ImportPlan()
        let found = downloads(in: folder, transfers: transfers(in: folder), groups: groups,
                              defaultFolder: downloadFolder, excluding: existing)
        plan.downloads = found.map(\.download)
        plan.categories = Set(found.compactMap(\.group)).sorted().map { name in
            let location = groups.values.first { $0.name == name }?.location
            return ImportedCategory(name: name, options: categoryOptions(savePath: location))
        }
        plan.settings = settings(from: preferences, defaults: defaults)
        return plan
    }

    // MARK: Downloads

    /// Each download in the app's folder, with the group it's in.
    static func downloads(in folder: URL, transfers: [String: Transfer], groups: [Int: Group],
                          defaultFolder: String, excluding existing: Set<String>,
                          now: Date = .now) -> [(download: ImportedDownload, group: String?)] {
        let fileManager = FileManager.default
        let resumeFolder = folder.appending(path: "Resume"), torrentFolder = folder.appending(path: "Torrents")
        guard let names = try? fileManager.contentsOfDirectory(atPath: resumeFolder.path) else { return [] }

        var found: [(download: ImportedDownload, group: String?)] = []
        var seen = existing
        for name in names.sorted() where name.hasSuffix(".resume") {
            // Transmission 4 names the files by hash, and earlier versions by name and part of it.
            let base = String(name.dropLast(".resume".count))
            guard let data = try? Data(contentsOf: resumeFolder.appending(path: name)),
                  let resume = try? decode(data)
            else { continue }

            let metadata = try? Data(contentsOf: torrentFolder.appending(path: "\(base).torrent"))
            let magnet = metadata == nil
                ? (try? String(contentsOf: torrentFolder.appending(path: "\(base).magnet"), encoding: .utf8)).flatMap(MagnetLink.init)
                : nil
            let hash = metadata.flatMap { try? TorrentMetadata(data: $0).infoHash } ?? magnet?.infoHash
            guard let hash, !seen.contains(hash) else { continue }

            let transfer = transfers[hash]
            let group = transfer?.group.flatMap { groups[$0]?.name }
            guard let download = download(hash: hash, metadata: metadata, magnet: magnet, resume: resume,
                                          isActive: transfer?.isActive, category: group,
                                          defaultFolder: defaultFolder, now: now)
            else { continue }
            seen.insert(hash)
            found.append((download, group))
        }
        return found
    }

    /// The engine's files for one of the app's downloads.
    static func download(hash: String, metadata: Data?, magnet: MagnetLink?, resume: BencodeValue,
                         isActive: Bool?, category: String?, defaultFolder: String,
                         now: Date = .now) -> ImportedDownload? {
        let fileManager = FileManager.default
        guard let hashBytes = Data(hex: hash), hashBytes.count == 20 else { return nil }

        // The torrent's files as the engine numbers them, padding included.
        var layout: [(path: String, isPadding: Bool)] = []
        var torrentName = magnet?.displayName ?? ""
        if let metadata {
            guard let info = try? decode(metadata)["info"], info["pieces"] != nil,
                  let torrent = try? TorrentMetadata(data: metadata)
            else { return nil }
            torrentName = torrent.name
            if let entries = info["files"]?.list {
                layout = entries.map {
                    (path: ([torrent.name] + TorrentMetadata.pathComponents(of: $0)).joined(separator: "/"),
                     isPadding: TorrentMetadata.isPadding($0))
                }
            } else {
                layout = [(path: torrent.name, isPadding: false)]
            }
        }

        // Transmission may or may not count padding files; its lists match one or the other.
        let dnd = resume["dnd"]?.list?.map { $0.integer ?? 0 } ?? []
        let priority = resume["priority"]?.list?.map { $0.integer ?? 0 } ?? []
        let names = resume["files"]?.list?.map { $0.string ?? "" } ?? []
        let counted = max(dnd.count, priority.count, names.count)
        let realFiles = layout.indices.filter { !layout[$0].isPadding }
        let engineIndex: [Int]? = counted == layout.count ? Array(layout.indices)
            : counted == realFiles.count ? realFiles : nil

        // Normal and low become qBittorrent's Normal, and high its High.
        var priorities = layout.map { $0.isPadding ? 0 : 1 }
        var mapped = Array(repeating: "", count: layout.count)
        var onDisk = layout.map(\.path)
        if let engineIndex {
            for (index, file) in engineIndex.enumerated() where !layout[file].isPadding {
                if index < dnd.count, dnd[index] != 0 {
                    priorities[file] = 0
                } else if index < priority.count, priority[index] > 0 {
                    priorities[file] = 6
                }
                // A file renamed in Transmission.
                if index < names.count, !names[index].isEmpty,
                   names[index].precomposedStringWithCanonicalMapping != layout[file].path.precomposedStringWithCanonicalMapping {
                    mapped[file] = names[index]
                    onDisk[file] = names[index]
                }
            }
        }

        // An unfinished download may still be in Transmission's incomplete folder.
        let destination = resume["destination"]?.string ?? defaultFolder
        let incompleteFolder = resume["incomplete-dir"]?.string
        let finishedAt = resume["done-date"]?.integer ?? 0
        let isDone = finishedAt > 0 && resume["progress"]?["pieces"]?.string != "none"
        func holdsFiles(_ folder: String) -> Bool {
            realFiles.prefix(20).contains { file in
                let path = URL(filePath: folder).appending(path: onDisk[file]).path
                return fileManager.fileExists(atPath: path) || fileManager.fileExists(atPath: path + ".part")
            }
        }
        let usesIncompleteFolder = incompleteFolder.map { !isDone && (holdsFiles($0) || !holdsFiles(destination)) } ?? false
        let dataFolder = usesIncompleteFolder ? incompleteFolder ?? destination : destination

        // Transmission adds `.part` to unfinished files; the engine looks for their own names.
        let renames: [ImportedDownload.Rename] = realFiles.compactMap { file in
            let target = URL(filePath: dataFolder).appending(path: onDisk[file])
            let part = URL(filePath: target.path + ".part")
            guard !fileManager.fileExists(atPath: target.path), fileManager.fileExists(atPath: part.path) else { return nil }
            return ImportedDownload.Rename(from: part, to: target)
        }

        let displayName = resume["name"]?.string ?? torrentName
        let isRunning = isActive ?? (resume["paused"]?.integer == 0)
        let downloadingTime = resume["downloading-time-seconds"]?.integer ?? 0
        let seedingTime = resume["seeding-time-seconds"]?.integer ?? 0

        var entries: [String: BencodeValue] = [
            "file-format": .text("libtorrent resume file"),
            "file-version": .integer(1),
            "info-hash": .bytes(hashBytes),
            "name": .text(torrentName.isEmpty ? displayName : torrentName),
            "save_path": .text(dataFolder),
            "added_time": .integer(resume["added-date"]?.integer ?? Int64(now.timeIntervalSince1970)),
            "total_uploaded": .integer(resume["uploaded"]?.integer ?? 0),
            "total_downloaded": .integer(resume["downloaded"]?.integer ?? 0),
            "active_time": .integer(downloadingTime + seedingTime),
            "seeding_time": .integer(seedingTime),
            "finished_time": .integer(seedingTime),
            "sequential_download": .integer(resume["sequential_download"]?.integer == 1 ? 1 : 0),
            "qBt-savePath": .text(destination),
            "qBt-downloadPath": .text(usesIncompleteFolder ? dataFolder : ""),
            "qBt-category": .text(category ?? ""),
            "qBt-tags": .list(labels(in: resume).map(BencodeValue.text)),
            "qBt-name": .text(displayName.precomposedStringWithCanonicalMapping
                              == torrentName.precomposedStringWithCanonicalMapping ? "" : displayName),
            "qBt-ratioLimit": .integer(Int64(shareLimit(resume["ratio-limit"], mode: "ratio-mode", value: "ratio-limit") * 1_000)),
            "qBt-seedingTimeLimit": .integer(-2),
            "qBt-inactiveSeedingTimeLimit": .integer(Int64(shareLimit(resume["idle-limit"], mode: "idle-mode", value: "idle-limit"))),
            "qBt-shareLimitAction": .text("Default"),
            "qBt-seedStatus": .integer(isDone ? 1 : 0),
            "qBt-contentLayout": .text("Original"),
            "qBt-firstLastPiecePriority": .integer(0),
        ]
        if metadata != nil {
            // Running, so the engine checks the files, and stopped once it has
            // if it was stopped in Transmission.
            entries["paused"] = .integer(0)
            entries["auto_managed"] = .integer(1)
            entries["qBt-stopCondition"] = .text(isRunning ? "None" : "FilesChecked")
            entries["file_priority"] = .list(priorities.map { .integer(Int64($0)) })
            if mapped.contains(where: { !$0.isEmpty }) {
                entries["mapped_files"] = .list(mapped.map(BencodeValue.text))
            }
        } else {
            // There's nothing to check before its details arrive.
            entries["paused"] = .integer(isRunning ? 0 : 1)
            entries["auto_managed"] = .integer(isRunning ? 1 : 0)
            entries["qBt-stopCondition"] = .text("None")
            entries["trackers"] = .list((magnet?.trackers ?? []).map { .list([.text($0)]) })
        }
        if isDone { entries["completed_time"] = .integer(finishedAt) }
        if let limit = speedLimit(resume["speed-limit-down"]) { entries["download_rate_limit"] = .integer(limit) }
        if let limit = speedLimit(resume["speed-limit-up"]) { entries["upload_rate_limit"] = .integer(limit) }
        if let peers = compactPeers(resume["peers2"], size: 6) { entries["peers"] = .bytes(peers) }
        if let peers = compactPeers(resume["peers2-6"], size: 18) { entries["peers6"] = .bytes(peers) }

        return ImportedDownload(hash: hash, name: displayName, metadata: metadata,
                                resumeData: BencodeValue.dict(entries).encoded, renames: renames)
    }

    private static func decode(_ data: Data) throws -> BencodeValue {
        var decoder = BencodeDecoder(data: data)
        return try decoder.decode()
    }

    private static func labels(in resume: BencodeValue) -> [String] {
        (resume["labels"]?.list ?? []).compactMap(\.string)
            .map { $0.replacingOccurrences(of: ",", with: " ").trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// A ratio or idle limit in qBittorrent's terms: -2 to follow the global
    /// setting, -1 for none, or the download's own.
    private static func shareLimit(_ value: BencodeValue?, mode modeKey: String, value valueKey: String) -> Double {
        switch value?[modeKey]?.integer {
        case 1:
            let limit = value?[valueKey]
            return limit?.integer.map(Double.init) ?? limit?.string.flatMap(Double.init) ?? -2
        case 2: return -1
        default: return -2
        }
    }

    /// The download's own speed limit in bytes per second, when it has one.
    private static func speedLimit(_ value: BencodeValue?) -> Int64? {
        guard let value, value["use-speed-limit"]?.integer == 1 else { return nil }
        // Transmission 2.x kept kilobytes.
        guard let limit = value["speed-Bps"]?.integer ?? value["speed"]?.integer.map({ $0 * 1_024 }), limit > 0 else { return nil }
        return limit
    }

    /// Peers Transmission knew, so the download finds them again quickly.
    private static func compactPeers(_ value: BencodeValue?, size: Int) -> Data? {
        let addresses = (value?.list ?? []).prefix(200).compactMap { $0["socket_address"]?.data }.filter { $0.count == size }
        return addresses.isEmpty ? nil : addresses.reduce(into: Data()) { $0.append($1) }
    }

    // MARK: The app's lists

    /// How the app lists each download, by hash, from `Transfers.plist`.
    static func transfers(in folder: URL) -> [String: Transfer] {
        guard let data = try? Data(contentsOf: folder.appending(path: "Transfers.plist")),
              let list = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [[String: Any]]
        else { return [:] }
        var transfers: [String: Transfer] = [:]
        for entry in list {
            guard let hash = (entry["TorrentHash"] as? String)?.lowercased() else { continue }
            let isActive = entry["Active"] as? Bool == true || entry["WaitToStart"] as? Bool == true
            let group = (entry["GroupValue"] as? Int).flatMap { $0 >= 0 ? $0 : nil }
            transfers[hash] = Transfer(isActive: isActive, group: group)
        }
        return transfers
    }

    /// The app's groups by number, from the archive in its settings.
    static func groups(from archive: Data?) -> [Int: Group] {
        guard let archive,
              let list = (try? NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, NSDictionary.self, NSString.self, NSNumber.self, NSColor.self,
                            NSPredicate.self, NSData.self, NSURL.self],
                from: archive)) as? [[String: Any]]
        else { return [:] }
        var groups: [Int: Group] = [:]
        for entry in list {
            guard let index = entry["Index"] as? Int, let name = entry["Name"] as? String,
                  !name.trimmingCharacters(in: .whitespaces).isEmpty
            else { continue }
            let location = entry["UsesCustomDownloadLocation"] as? Bool == true
                ? entry["CustomDownloadLocation"] as? String : nil
            groups[index] = Group(name: name.trimmingCharacters(in: .whitespaces), location: location)
        }
        return groups
    }

    private static func categoryOptions(savePath: String?) -> Data {
        (try? JSONSerialization.data(withJSONObject: ["save_path": savePath ?? ""])) ?? Data("{}".utf8)
    }

    // MARK: Settings

    /// The app's settings as it ships them, for the ones its user didn't change.
    static var appDefaults: [String: Any] {
        var defaults = builtInDefaults
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier),
           let shipped = NSDictionary(contentsOf: app.appending(path: "Contents/Resources/Defaults.plist")) as? [String: Any] {
            defaults.merge(shipped) { $1 }
        }
        return defaults
    }

    private static var builtInDefaults: [String: Any] { [
        "CheckDownload": false, "DownloadLimit": 100, "CheckUpload": false, "UploadLimit": 50,
        "RatioCheck": false, "RatioLimit": 2, "BindPort": 51_413, "RandomPort": false, "NatTraversal": true,
        "UTPGlobal": true, "DHTGlobal": true, "PEXGlobal": true, "LocalPeerDiscoveryGlobal": false,
        "EncryptionPrefer": true, "EncryptionRequire": false, "PeersTotal": 200, "PeersTorrent": 60,
        "DownloadLocationConstant": false, "DownloadFolder": "~/Downloads",
    ] }

    /// The settings the app's user chose, in OrbTorrent's terms. `user` holds
    /// only what they changed; `defaults` fills in the rest of each setting.
    static func settings(from user: [String: Any], defaults: [String: Any]) -> ImportedSettings {
        func chose(_ keys: String...) -> Bool { keys.contains { user[$0] != nil } }
        func bool(_ key: String) -> Bool { (user[key] ?? defaults[key]) as? Bool ?? false }
        func number(_ key: String) -> Double? { ((user[key] ?? defaults[key]) as? NSNumber)?.doubleValue }
        func count(_ key: String) -> Int? { chose(key) ? number(key).map { Int($0) } : nil }

        var settings = ImportedSettings()
        // Transmission's KB/s, shown as the same number in OrbTorrent.
        if chose("CheckDownload", "DownloadLimit") {
            settings.downloadLimit = bool("CheckDownload") ? Int64(max(number("DownloadLimit") ?? 0, 1)) * 1_024 : 0
        }
        if chose("CheckUpload", "UploadLimit") {
            settings.uploadLimit = bool("CheckUpload") ? Int64(max(number("UploadLimit") ?? 0, 1)) * 1_024 : 0
        }
        // Otherwise each download goes next to its .torrent file.
        if chose("DownloadLocationConstant", "DownloadFolder"), bool("DownloadLocationConstant"),
           let folder = (user["DownloadFolder"] ?? defaults["DownloadFolder"]) as? String {
            settings.savePath = (folder as NSString).expandingTildeInPath
        }
        if chose("RatioCheck", "RatioLimit") {
            settings.ratioLimit = bool("RatioCheck") ? number("RatioLimit") ?? 2 : -1
            settings.ratioAction = .stop
        }
        if chose("BindPort", "RandomPort"), !bool("RandomPort"), let port = number("BindPort") {
            settings.listenPort = Int(port)
        }
        if chose("NatTraversal") { settings.portMapping = bool("NatTraversal") }
        if chose("UTPGlobal") { settings.peerProtocol = bool("UTPGlobal") ? .both : .tcp }
        if chose("DHTGlobal") { settings.dht = bool("DHTGlobal") }
        if chose("PEXGlobal") { settings.pex = bool("PEXGlobal") }
        if chose("LocalPeerDiscoveryGlobal") { settings.lsd = bool("LocalPeerDiscoveryGlobal") }
        if chose("EncryptionRequire", "EncryptionPrefer") {
            settings.encryption = bool("EncryptionRequire") ? .require : .prefer
        }
        settings.maxConnections = count("PeersTotal")
        settings.maxConnectionsPerTorrent = count("PeersTorrent")
        return settings
    }
}

extension Data {
    /// Bytes from hexadecimal text, such as an info hash.
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
