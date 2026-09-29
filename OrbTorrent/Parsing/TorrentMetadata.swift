import CryptoKit
import Foundation

/// What OrbTorrent can read from a `.torrent` file before handing it to the engine.
struct TorrentMetadata: Sendable {
    struct File: Sendable, Identifiable {
        let id: Int
        let path: String
        let size: Int64
    }

    /// The identifier qBittorrent uses for the torrent: the v1 info hash, or the
    /// first 20 bytes of the v2 info hash for v2-only torrents, in lowercase hex.
    let infoHash: String
    let name: String
    let files: [File]
    let comment: String?
    let isPrivate: Bool

    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }

    enum ParseError: LocalizedError {
        case notATorrent

        var errorDescription: String? { "This file isn't a valid torrent." }
    }

    init(infoHash: String, name: String, files: [File], comment: String? = nil, isPrivate: Bool = false) {
        self.infoHash = infoHash
        self.name = name
        self.files = files
        self.comment = comment
        self.isPrivate = isPrivate
    }

    init(data: Data) throws {
        var decoder = BencodeDecoder(data: data)
        let root: BencodeValue
        do {
            root = try decoder.decode()
        } catch {
            throw ParseError.notATorrent
        }
        guard let info = root["info"], let infoRange = decoder.infoRange else {
            throw ParseError.notATorrent
        }

        let infoBytes = data.subdata(in: (data.startIndex + infoRange.lowerBound)..<(data.startIndex + infoRange.upperBound))
        let metaVersion = info["meta version"]?.integer ?? 1
        let hasV1Pieces = info["pieces"] != nil
        if metaVersion >= 2 && !hasV1Pieces {
            infoHash = SHA256.hash(data: infoBytes).prefix(20).hexString
        } else {
            infoHash = Insecure.SHA1.hash(data: infoBytes).hexString
        }

        let displayName = info["name.utf-8"]?.string ?? info["name"]?.string ?? "Untitled"
        name = displayName
        comment = root["comment.utf-8"]?.string ?? root["comment"]?.string
        isPrivate = info["private"]?.integer == 1

        if let list = info["files"]?.list {
            // The engine leaves out padding files, which only line files up
            // with pieces, and numbers the rest.
            files = list.filter { !Self.isPadding($0) }.enumerated().map { index, entry in
                File(id: index,
                     path: ([displayName] + Self.pathComponents(of: entry)).joined(separator: "/"),
                     size: entry["length"]?.integer ?? 0)
            }
        } else if let length = info["length"]?.integer {
            files = [File(id: 0, path: displayName, size: length)]
        } else if let tree = info["file tree"] {
            var collected: [(String, Int64)] = []
            Self.walk(tree, path: [displayName], into: &collected)
            files = collected.enumerated().map { File(id: $0.offset, path: $0.element.0, size: $0.element.1) }
        } else {
            files = []
        }
    }

    static func pathComponents(of entry: BencodeValue) -> [String] {
        (entry["path.utf-8"] ?? entry["path"])?.list?.compactMap(\.string) ?? []
    }

    /// Whether a file entry is padding (BEP 47), or BitComet's older kind.
    static func isPadding(_ entry: BencodeValue) -> Bool {
        entry["attr"]?.string?.contains("p") == true
            || pathComponents(of: entry).joined(separator: "/").contains("_____padding_file_")
    }

    /// Flattens a BitTorrent v2 `file tree` dictionary.
    private static func walk(_ node: BencodeValue, path: [String], into files: inout [(String, Int64)]) {
        guard let entries = node.entries else { return }
        for (key, value) in entries {
            let name = String(data: key, encoding: .utf8) ?? ""
            if name.isEmpty {
                files.append((path.joined(separator: "/"), value["length"]?.integer ?? 0))
            } else {
                walk(value, path: path + [name], into: &files)
            }
        }
    }
}

extension Sequence where Element == UInt8 {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
