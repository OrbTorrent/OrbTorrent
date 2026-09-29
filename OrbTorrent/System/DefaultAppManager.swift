import AppKit
import Observation
import UniformTypeIdentifiers

/// Checks and sets OrbTorrent as the Mac's handler for magnet links and `.torrent` files.
@MainActor
@Observable
final class DefaultAppManager {
    private(set) var handlesMagnetLinks = false
    private(set) var handlesTorrentFiles = false

    var isDefault: Bool { handlesMagnetLinks && handlesTorrentFiles }

    /// The app currently opening magnet links, if it isn't OrbTorrent.
    private(set) var currentMagnetHandlerName: String?

    func refresh() {
        let ownIdentifier = Bundle.main.bundleIdentifier
        let workspace = NSWorkspace.shared

        let magnetApp = URL(string: "magnet:?xt=urn:btih:0000000000000000000000000000000000000000")
            .flatMap { workspace.urlForApplication(toOpen: $0) }
        handlesMagnetLinks = magnetApp.flatMap { Bundle(url: $0)?.bundleIdentifier } == ownIdentifier
        currentMagnetHandlerName = handlesMagnetLinks ? nil : magnetApp.map { $0.deletingPathExtension().lastPathComponent }

        let torrentApp = workspace.urlForApplication(toOpen: .torrent)
        handlesTorrentFiles = torrentApp.flatMap { Bundle(url: $0)?.bundleIdentifier } == ownIdentifier
    }

    func makeDefault() async throws {
        let app = Bundle.main.bundleURL
        try await NSWorkspace.shared.setDefaultApplication(at: app, toOpenURLsWithScheme: "magnet")
        try await NSWorkspace.shared.setDefaultApplication(at: app, toOpen: .torrent)
        refresh()
    }
}
