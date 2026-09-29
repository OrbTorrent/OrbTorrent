import AppKit
import Foundation

/// Opening, revealing and trashing downloaded files.
@MainActor
enum FileActions {
    /// The torrent's top-level file or folder on disk.
    static func contentURL(of torrent: Torrent) -> URL? {
        let path = torrent.contentPath.isEmpty ? torrent.savePath : torrent.contentPath
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    static func url(of file: TorrentFile, in torrent: Torrent) -> URL {
        URL(fileURLWithPath: torrent.savePath).appending(path: file.name)
    }

    static func exists(_ url: URL?) -> Bool {
        guard let url else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Opens a single-file download in its default app, or a folder in Finder.
    static func open(_ torrent: Torrent) {
        guard let url = contentURL(of: torrent), exists(url) else {
            revealSaveFolder(of: torrent)
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func open(_ file: TorrentFile, in torrent: Torrent) {
        let url = url(of: file, in: torrent)
        if exists(url) {
            NSWorkspace.shared.open(url)
        } else {
            reveal(torrent)
        }
    }

    static func reveal(_ torrent: Torrent) {
        guard let url = contentURL(of: torrent), exists(url) else {
            revealSaveFolder(of: torrent)
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    static func reveal(_ file: TorrentFile, in torrent: Torrent) {
        let url = url(of: file, in: torrent)
        if exists(url) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            reveal(torrent)
        }
    }

    static func revealSaveFolder(of torrent: Torrent) {
        guard !torrent.savePath.isEmpty else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: torrent.savePath, isDirectory: true))
    }

    /// Moves a torrent's downloaded data to the Trash, so it can be put back.
    ///
    /// Only paths *inside* the torrent's save folder are ever touched: when a
    /// torrent has its own folder that folder is trashed, otherwise each of its
    /// files is trashed individually. The save folder itself never is. The
    /// engine's parts file for the torrent goes too.
    @discardableResult
    static func trashContent(of torrent: Torrent, files: [TorrentFile]) -> [Error] {
        var errors: [Error] = []
        let targets = trashTargets(for: torrent, files: files) + [partsFile(of: torrent)].compactMap { $0 }
        for target in targets where exists(target) {
            do {
                try FileManager.default.trashItem(at: target, resultingItemURL: nil)
            } catch {
                errors.append(error)
            }
        }
        return errors
    }

    /// The paths `trashContent` would move to the Trash.
    nonisolated static func trashTargets(for torrent: Torrent, files: [TorrentFile],
                                         home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [URL] {
        guard !torrent.savePath.isEmpty else { return [] }
        let saveFolder = URL(fileURLWithPath: torrent.savePath, isDirectory: true).standardizedFileURL

        let targets: [URL]
        if !torrent.contentPath.isEmpty,
           case let content = URL(fileURLWithPath: torrent.contentPath).standardizedFileURL,
           content.path != saveFolder.path,
           isInside(content, saveFolder) {
            targets = [content]
        } else {
            targets = files
                .map { saveFolder.appending(path: $0.name).standardizedFileURL }
                .filter { isInside($0, saveFolder) }
        }
        return targets.filter { !isProtectedRoot($0, home: home) }
    }

    /// The engine's hidden file in the save folder holding the pieces of files
    /// that were skipped, which are shared with files that weren't.
    nonisolated static func partsFile(of torrent: Torrent) -> URL? {
        guard !torrent.savePath.isEmpty, !torrent.hash.isEmpty else { return nil }
        return URL(fileURLWithPath: torrent.savePath, isDirectory: true).appending(path: ".\(torrent.hash).parts")
    }

    nonisolated private static func isInside(_ url: URL, _ folder: URL) -> Bool {
        let folderPath = folder.path.hasSuffix("/") ? folder.path : folder.path + "/"
        return url.path.hasPrefix(folderPath)
    }

    /// The file system root, the home folder and the standard folders in it.
    nonisolated private static func isProtectedRoot(_ url: URL, home: URL) -> Bool {
        let home = home.standardizedFileURL
        let protected: [URL] = [
            URL(fileURLWithPath: "/"),
            home,
            home.appending(path: "Downloads"),
            home.appending(path: "Desktop"),
            home.appending(path: "Documents"),
            home.appending(path: "Movies"),
            home.appending(path: "Music"),
            home.appending(path: "Pictures"),
        ].map(\.standardizedFileURL)
        return protected.contains { $0.path == url.path }
    }
}
