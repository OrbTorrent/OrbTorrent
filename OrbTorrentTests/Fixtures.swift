import Foundation
@testable import OrbTorrent

/// Builds API models from JSON shaped like qBittorrent 5.2's responses.
enum Fixtures {
    static func torrent(hash: String = "abc",
                        name: String = "Show",
                        savePath: String,
                        contentPath: String,
                        progress: Double = 0.5,
                        state: String = "downloading",
                        size: Int64 = 1_000,
                        addedOn: Date? = nil) -> Torrent {
        var json: [String: Any] = [
            "hash": hash, "name": name, "state": state, "progress": progress,
            "save_path": savePath, "content_path": contentPath,
            "size": size, "total_size": size, "amount_left": Int64(Double(size) * (1 - progress)),
            "dlspeed": 10, "upspeed": 0, "eta": 60,
        ]
        if let addedOn { json["added_on"] = Int64(addedOn.timeIntervalSince1970) }
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(Torrent.self, from: data)
    }

    static func file(_ index: Int, _ name: String, progress: Double = 0, priority: Int = 1) -> TorrentFile {
        TorrentFile(index: index, name: name, size: 100, progress: progress,
                    priority: FilePriority(rawValue: priority) ?? .normal, availability: 1)
    }
}

/// Throwaway settings for tests. Named by a path in the temporary folder, so
/// they live there rather than in ~/Library/Preferences: the preferences
/// service can write an emptied file back after it's deleted.
enum TestDefaults {
    static func makeSuiteName() -> String {
        FileManager.default.temporaryDirectory.appending(path: "orbtorrent-tests-\(UUID().uuidString)").path
    }

    static func remove(_ suite: String) {
        UserDefaults().removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(atPath: suite + ".plist")
    }
}
