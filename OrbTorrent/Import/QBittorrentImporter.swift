import Foundation

/// Reads the qBittorrent app's downloads, categories and settings for importing.
///
/// qBittorrent stores each torrent as `<hash>.torrent` plus `<hash>.fastresume`
/// in its `BT_backup` folder. OrbTorrent's engine is qBittorrent too, so they
/// come over as they are, progress included.
enum QBittorrentImporter {
    static let bundleIdentifier = "org.qbittorrent.qBittorrent"

    static var resumeDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "qBittorrent/BT_backup", directoryHint: .isDirectory)
    }

    /// Qt keeps an app's settings file in `~/.config` on macOS.
    static var settingsFile: URL {
        URL.homeDirectory.appending(path: ".config/qBittorrent/qBittorrent.ini")
    }

    static var categoriesFile: URL {
        URL.libraryDirectory.appending(path: "Preferences/qBittorrent/categories.json")
    }

    static func plan(excluding existing: Set<String>) -> ImportPlan {
        var plan = ImportPlan()
        plan.downloads = downloads(in: resumeDirectory, excluding: existing)
        plan.categories = categories(from: (try? Data(contentsOf: categoriesFile)) ?? Data())
        plan.settings = settings(from: IniFile(contents: (try? String(contentsOf: settingsFile, encoding: .utf8)) ?? ""))
        return plan
    }

    /// Each download in `BT_backup`, including magnet links still waiting
    /// for their details, which have no `.torrent` yet.
    static func downloads(in folder: URL, excluding existing: Set<String>) -> [ImportedDownload] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return names.filter { $0.hasSuffix(".fastresume") }.sorted().compactMap { name in
            let hash = String(name.dropLast(".fastresume".count))
            guard !existing.contains(hash),
                  let resumeData = try? Data(contentsOf: folder.appending(path: name))
            else { return nil }
            let metadata = try? Data(contentsOf: folder.appending(path: "\(hash).torrent"))
            return ImportedDownload(hash: hash, name: displayName(resumeData, metadata) ?? hash,
                                    metadata: metadata, resumeData: resumeData)
        }
    }

    private static func displayName(_ resumeData: Data, _ metadata: Data?) -> String? {
        var decoder = BencodeDecoder(data: resumeData)
        let resume = try? decoder.decode()
        let names = [resume?["qBt-name"]?.string, resume?["name"]?.string,
                     metadata.flatMap { try? TorrentMetadata(data: $0).name }]
        return names.lazy.compactMap { $0 }.first { !$0.isEmpty }
    }

    /// The app's categories, with their own save locations and limits.
    static func categories(from data: Data) -> [ImportedCategory] {
        guard let list = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return [] }
        return list.keys.sorted().compactMap { name in
            guard let options = list[name] as? [String: Any],
                  let data = try? JSONSerialization.data(withJSONObject: options)
            else { return nil }
            return ImportedCategory(name: name, options: data)
        }
    }

    /// The settings the app records, in OrbTorrent's terms.
    static func settings(from ini: IniFile) -> ImportedSettings {
        func value(_ key: String) -> String? { ini.value("Session\\\(key)", in: "BitTorrent") }
        func number(_ key: String) -> Int? { value(key).flatMap { Int($0) } }
        func bool(_ key: String) -> Bool? { value(key).map { $0 == "true" } }

        var settings = ImportedSettings()
        // qBittorrent's KiB/s.
        settings.downloadLimit = number("GlobalDLSpeedLimit").map { Int64(max($0, 0)) * 1_024 }
        settings.uploadLimit = number("GlobalUPSpeedLimit").map { Int64(max($0, 0)) * 1_024 }
        settings.savePath = value("DefaultSavePath").flatMap { $0.isEmpty ? nil : ($0 as NSString).expandingTildeInPath }
        settings.ratioLimit = value("GlobalMaxRatio").flatMap(Double.init).map { $0 < 0 ? -1 : $0 }
        let actions: [String: EnginePreferences.RatioAction] = [
            "Stop": .stop, "Remove": .remove, "RemoveWithContent": .removeWithFiles, "EnableSuperSeeding": .superSeed,
        ]
        settings.ratioAction = value("ShareLimitAction").flatMap { actions[$0] }
        settings.listenPort = number("Port")
        settings.portMapping = ini.value("PortForwardingEnabled", in: "Network").map { $0 == "true" }
        let protocols: [String: EnginePreferences.PeerProtocol] = ["Both": .both, "TCP": .tcp, "UTP": .utp]
        settings.peerProtocol = value("BTProtocol").flatMap { protocols[$0] }
        settings.dht = bool("DHTEnabled")
        settings.pex = bool("PeXEnabled")
        settings.lsd = bool("LSDEnabled")
        settings.encryption = number("Encryption").flatMap(EnginePreferences.Encryption.init)
        settings.maxConnections = number("MaxConnections")
        settings.maxConnectionsPerTorrent = number("MaxConnectionsPerTorrent")
        return settings
    }
}
