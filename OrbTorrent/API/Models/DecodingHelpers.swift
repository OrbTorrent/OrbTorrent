import Foundation

extension KeyedDecodingContainer {
    /// Decodes a value, falling back to `defaultValue` when the key is missing,
    /// null, or of an unexpected type. qBittorrent adds and renames fields
    /// between releases, so the app never fails a whole refresh over one field.
    func value<T: Decodable>(_ key: Key, default defaultValue: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? defaultValue
    }

    /// Decodes a Unix timestamp, treating zero and negative values as "never".
    func date(_ key: Key) -> Date? {
        let seconds = value(key, default: Int64(0))
        return seconds > 0 ? Date(timeIntervalSince1970: TimeInterval(seconds)) : nil
    }
}
