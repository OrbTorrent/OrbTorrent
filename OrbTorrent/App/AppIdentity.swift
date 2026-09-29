import Foundation

/// Which OrbTorrent this is: the app people use, or OrbTorrent Dev, built
/// alongside it while OrbTorrent is developed. Dev has its own bundle
/// identifier, and from it its own library, settings and Keychain items, so
/// the two can run side by side.
enum AppIdentity {
    /// The released app's bundle identifier.
    static let releaseIdentifier = "com.orbtorrent.mac"

    static var bundleIdentifier: String { Bundle.main.bundleIdentifier ?? releaseIdentifier }

    /// Whether this is OrbTorrent Dev.
    static var isDevelopment: Bool { isDevelopment(bundleIdentifier) }

    /// "OrbTorrent" or "OrbTorrent Dev". Also the name of its folder in
    /// Application Support.
    static var name: String { name(for: bundleIdentifier) }

    /// What OrbTorrent Dev leaves to OrbTorrent, for where their settings differ.
    static let developmentNote = "OrbTorrent Dev is for trying changes. It keeps its own downloads and settings, and leaves opening links and files, and starting at login, to OrbTorrent."

    static func isDevelopment(_ bundleIdentifier: String) -> Bool {
        bundleIdentifier.hasSuffix(".dev")
    }

    static func name(for bundleIdentifier: String) -> String {
        isDevelopment(bundleIdentifier) ? "OrbTorrent Dev" : "OrbTorrent"
    }
}
