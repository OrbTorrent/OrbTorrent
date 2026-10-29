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

    /// The most files a torrent may list, and the most folders deep each may
    /// be, so a file built to be huge is refused instead of using up memory.
    struct Limits: Sendable {
        var files = 1_000_000
        var pathComponents = 4_096
    }

    /// The most all of a torrent's files may add up to, 8 PiB: far more than
    /// any real torrent, and low enough that adding up sizes never overflows.
    static let maximumTotalSize: Int64 = 1 << 53

    enum ParseError: LocalizedError {
        case notATorrent
        /// More files, or files deeper in folders, than the limits above.
        case tooLarge

        var errorDescription: String? {
            switch self {
            case .notATorrent: "This file isn't a valid torrent."
            case .tooLarge: "This torrent lists more files than OrbTorrent can open."
            }
        }
    }

    init(infoHash: String, name: String, files: [File], comment: String? = nil, isPrivate: Bool = false) {
        self.infoHash = infoHash
        self.name = name
        self.files = files
        self.comment = comment
        self.isPrivate = isPrivate
    }

    init(data: Data, limits: Limits = Limits()) throws {
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
            guard list.count <= limits.files,
                  !list.contains(where: { Self.pathComponents(of: $0).count > limits.pathComponents }) else {
                throw ParseError.tooLarge
            }
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
            guard Self.walk(tree, path: [displayName], into: &collected, limit: limits.files) else { throw ParseError.tooLarge }
            files = collected.enumerated().map { File(id: $0.offset, path: $0.element.0, size: $0.element.1) }
        } else {
            files = []
        }
        guard Self.sizesAddUp(files) else { throw ParseError.notATorrent }
    }

    /// Whether every size is zero or more and they add up to no more than
    /// `maximumTotalSize`, so totals of them can't overflow.
    private static func sizesAddUp(_ files: [File]) -> Bool {
        var total: Int64 = 0
        for file in files {
            guard file.size >= 0 else { return false }
            let (sum, overflow) = total.addingReportingOverflow(file.size)
            guard !overflow, sum <= maximumTotalSize else { return false }
            total = sum
        }
        return true
    }

    static func pathComponents(of entry: BencodeValue) -> [String] {
        (entry["path.utf-8"] ?? entry["path"])?.list?.compactMap(\.string) ?? []
    }

    /// Whether a file entry is padding (BEP 47), or BitComet's older kind.
    static func isPadding(_ entry: BencodeValue) -> Bool {
        entry["attr"]?.string?.contains("p") == true
            || pathComponents(of: entry).joined(separator: "/").contains("_____padding_file_")
    }

    /// Flattens a BitTorrent v2 `file tree` dictionary. False when it lists
    /// more files than the limit.
    private static func walk(_ node: BencodeValue, path: [String], into files: inout [(String, Int64)], limit: Int) -> Bool {
        guard let entries = node.entries else { return true }
        for (key, value) in entries {
            let name = String(data: key, encoding: .utf8) ?? ""
            if name.isEmpty {
                guard files.count < limit else { return false }
                files.append((path.joined(separator: "/"), value["length"]?.integer ?? 0))
            } else if !walk(value, path: path + [name], into: &files, limit: limit) {
                return false
            }
        }
        return true
    }
}

extension Sequence where Element == UInt8 {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
