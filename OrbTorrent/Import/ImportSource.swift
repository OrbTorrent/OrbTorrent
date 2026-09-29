import AppKit
import Foundation

/// Another torrent app whose downloads and settings OrbTorrent can bring over.
enum ImportSource: String, CaseIterable, Identifiable, Sendable {
    case transmission
    case qBittorrent

    var id: String { rawValue }

    var name: String {
        switch self {
        case .transmission: "Transmission"
        case .qBittorrent: "qBittorrent"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .transmission: TransmissionImporter.bundleIdentifier
        case .qBittorrent: QBittorrentImporter.bundleIdentifier
        }
    }

    /// Whether this Mac has the app's downloads or settings.
    var hasLibrary: Bool {
        let paths = switch self {
        case .transmission: [TransmissionImporter.folder.path]
        case .qBittorrent: [QBittorrentImporter.resumeDirectory.path, QBittorrentImporter.settingsFile.path]
        }
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    /// When the app last saved its downloads or settings, to tell which of
    /// two apps someone uses.
    var lastUsed: Date? {
        let paths = switch self {
        case .transmission:
            [TransmissionImporter.folder.appending(path: "Transfers.plist").path,
             URL.libraryDirectory.appending(path: "Preferences/\(bundleIdentifier).plist").path]
        case .qBittorrent: [QBittorrentImporter.resumeDirectory.path, QBittorrentImporter.settingsFile.path]
        }
        return paths.compactMap { try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date }.max()
    }

    @MainActor
    var icon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// Asks the app to quit and waits for it. It may ask its user first, as
    /// Transmission does while downloads are active.
    @MainActor
    func quit(within timeout: Duration = .seconds(30)) async -> Bool {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        running.forEach { $0.terminate() }
        let deadline = ContinuousClock.now + timeout
        while running.contains(where: { !$0.isTerminated }), ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        return running.allSatisfy(\.isTerminated)
    }

    /// What the app has for OrbTorrent, leaving out downloads it already has.
    func plan(excluding existing: Set<String>) -> ImportPlan {
        switch self {
        case .transmission: TransmissionImporter.plan(excluding: existing)
        case .qBittorrent: QBittorrentImporter.plan(excluding: existing)
        }
    }
}

/// What another app has for OrbTorrent.
struct ImportPlan: Sendable {
    var downloads: [ImportedDownload] = []
    /// Categories for the downloads, with their own save locations.
    var categories: [ImportedCategory] = []
    var settings = ImportedSettings()
}

/// A download from another app, as the pair of files OrbTorrent's engine
/// keeps for each one in `BT_backup`.
struct ImportedDownload: Sendable, Identifiable {
    struct Rename: Sendable, Equatable {
        let from: URL
        let to: URL
    }

    let hash: String
    let name: String
    /// The `.torrent`, or nil for a magnet link whose details haven't arrived.
    let metadata: Data?
    /// The engine's `.fastresume`.
    let resumeData: Data
    /// Unfinished files the other app named differently, such as
    /// Transmission's `.part`, to put back under their own names.
    var renames: [Rename] = []

    var id: String { hash }
}

/// One app to bring over, and what to bring from it.
struct ImportJob: Sendable {
    let source: ImportSource
    var includesDownloads = true
    var settings: [ImportedSetting] = []
}

/// A category as qBittorrent keeps it in `categories.json`.
struct ImportedCategory: Sendable, Equatable {
    let name: String
    /// A JSON object, such as `{"save_path": "/Volumes/Media"}`.
    let options: Data
}

enum ImportError: LocalizedError {
    case stillOpen(ImportSource)

    var errorDescription: String? {
        switch self {
        case .stillOpen(let source):
            "\(source.name) is still open. Quit it so the two apps don't use the same files, then try again."
        }
    }
}
