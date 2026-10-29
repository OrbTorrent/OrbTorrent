import Foundation

/// A parsed `magnet:` link.
struct MagnetLink: Sendable, Hashable {
    let uri: String
    /// qBittorrent's torrent ID for the link, in lowercase hex, when it can be derived.
    let infoHash: String?
    let displayName: String?
    /// The trackers the link names, in order.
    let trackers: [String]

    init?(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A space, line break or control character inside isn't part of a
        // link: the engine reads each line as a link of its own, or a file.
        guard trimmed.lowercased().hasPrefix("magnet:?"),
              trimmed.unicodeScalars.allSatisfy({ !Self.notInLinks.contains($0) }),
              let components = URLComponents(string: trimmed)
        else { return nil }

        uri = trimmed
        let items = components.queryItems ?? []
        // Magnet names are form-encoded: "+" means a space, "%2B" a plus sign.
        displayName = components.percentEncodedQueryItems?
            .first(where: { $0.name == "dn" })?.value?
            .replacingOccurrences(of: "+", with: " ")
            .removingPercentEncoding
        trackers = items.filter { $0.name == "tr" || $0.name.hasPrefix("tr.") }.compactMap(\.value).filter { !$0.isEmpty }

        let topics = items.filter { $0.name == "xt" || $0.name.hasPrefix("xt.") }.compactMap(\.value)
        if let v1 = topics.lazy.compactMap({ Self.hash(fromTopic: $0, prefix: "urn:btih:") }).first {
            infoHash = Self.normalizeV1(v1)
        } else if let v2 = topics.lazy.compactMap({ Self.hash(fromTopic: $0, prefix: "urn:btmh:") }).first,
                  v2.count == 68, v2.lowercased().hasPrefix("1220") {
            // Multihash: 0x12 (sha2-256), 0x20 (32 bytes). qBittorrent truncates to 20 bytes.
            infoHash = String(v2.dropFirst(4).prefix(40)).lowercased()
        } else {
            infoHash = nil
        }
    }

    /// The link with more trackers added after its own.
    func adding(trackers extra: [String]) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return extra.filter { !trackers.contains($0) }.reduce(uri) { link, tracker in
            link + "&tr=" + (tracker.addingPercentEncoding(withAllowedCharacters: allowed) ?? tracker)
        }
    }

    /// Returns the first magnet link found in arbitrary text, such as the clipboard.
    static func first(in text: String) -> MagnetLink? {
        guard let range = text.range(of: "magnet:?", options: .caseInsensitive) else { return nil }
        let candidate = text[range.lowerBound...].prefix { character in
            character != "\"" && character != "<" && !character.unicodeScalars.contains(where: notInLinks.contains)
        }
        return MagnetLink(String(candidate))
    }

    private static let notInLinks = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)

    private static func hash(fromTopic topic: String, prefix: String) -> String? {
        guard topic.lowercased().hasPrefix(prefix) else { return nil }
        return String(topic.dropFirst(prefix.count))
    }

    private static func normalizeV1(_ value: String) -> String? {
        if value.count == 40, value.allSatisfy(\.isHexDigit) {
            return value.lowercased()
        }
        if value.count == 32, let bytes = base32Decode(value.uppercased()) {
            return bytes.hexString
        }
        return nil
    }

    private static func base32Decode(_ text: String) -> [UInt8]? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var buffer: UInt64 = 0
        var bits = 0
        var output: [UInt8] = []
        for character in text {
            guard let index = alphabet.firstIndex(of: character) else { return nil }
            buffer = (buffer << 5) | UInt64(index)
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((buffer >> UInt64(bits)) & 0xFF))
            }
        }
        return output.count == 20 ? output : nil
    }
}
