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
        reveal([file], in: torrent)
    }

    /// Selects the files in Finder, or shows the download if none are on disk yet.
    static func reveal(_ files: [TorrentFile], in torrent: Torrent) {
        let urls = files.map { url(of: $0, in: torrent) }.filter { exists($0) }
        if urls.isEmpty {
            reveal(torrent)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
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

    // MARK: Files extensions added

    /// Where files an extension added next to a download's are now: each one
    /// still there, and inside the download's save folder.
    nonisolated static func addedFiles(_ paths: [String], in savePath: String) -> [URL] {
        guard !savePath.isEmpty else { return [] }
        // By the paths alone, the way they were recorded (ExtensionFileAdder.relativePath).
        let folder = URL(fileURLWithPath: savePath, isDirectory: true).standardized
        return paths.map { folder.appending(path: $0).standardized }.filter { url in
            var status = stat()
            return isInside(url, folder) && lstat(url.path, &status) == 0 && status.st_mode & S_IFMT == S_IFREG
        }
    }

    /// Shows the files an extension added, selected in Finder.
    static func revealAdded(_ paths: [String], of torrent: Torrent) {
        let urls = addedFiles(paths, in: torrent.savePath)
        guard !urls.isEmpty else { return revealSaveFolder(of: torrent) }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    /// Removes the files extensions added to a removed download, to the Trash
    /// or for good like its own files, then any of their folders left empty.
    nonisolated static func removeAdded(_ paths: [String], in savePath: String, trash: Bool) -> [Error] {
        var errors: [Error] = []
        let folder = URL(fileURLWithPath: savePath, isDirectory: true).standardized
        for url in addedFiles(paths, in: savePath) {
            do {
                if trash {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } else {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                errors.append(error)
            }
            // The engine leaves the download's folder while these are in it.
            var parent = url.deletingLastPathComponent()
            while isInside(parent, folder), rmdir(parent.path) == 0 {
                parent = parent.deletingLastPathComponent()
            }
        }
        return errors
    }

    /// Moves the files extensions added along with their download, keeping
    /// each one's place in it. The engine moves only the download's own.
    nonisolated static func moveAdded(_ paths: [String], from savePath: String, to destination: URL) {
        let source = URL(fileURLWithPath: savePath, isDirectory: true).standardized
        let destination = destination.standardized
        guard source.path != destination.path else { return }
        for url in addedFiles(paths, in: savePath) {
            let target = destination.appending(path: String(url.path.dropFirst(source.path.count + 1)))
            guard !FileManager.default.fileExists(atPath: target.path) else { continue }
            try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.moveItem(at: url, to: target)
        }
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
