import Foundation

/// Puts imported downloads and categories where OrbTorrent's engine finds
/// them the next time it starts.
enum ImportWriter {
    /// Writes each download the engine doesn't have yet and returns how many
    /// it wrote. The engine must be stopped.
    @discardableResult
    static func write(_ downloads: [ImportedDownload], categories: [ImportedCategory],
                      resumeDirectory: URL = EnginePaths.resumeDirectory,
                      categoriesFile: URL = EnginePaths.categoriesFile) throws -> Int {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
        var written = 0
        for download in downloads {
            let resume = resumeDirectory.appending(path: "\(download.hash).fastresume")
            guard !fileManager.fileExists(atPath: resume.path) else { continue }
            // Left as they are if this fails; the engine then downloads those files again.
            for rename in download.renames where !fileManager.fileExists(atPath: rename.to.path) {
                try? fileManager.moveItem(at: rename.from, to: rename.to)
            }
            if let metadata = download.metadata {
                try metadata.write(to: resumeDirectory.appending(path: "\(download.hash).torrent"), options: .atomic)
            }
            try download.resumeData.write(to: resume, options: .atomic)
            written += 1
        }
        try add(categories, to: categoriesFile)
        return written
    }

    /// Adds the categories the engine doesn't have, keeping its own as they are.
    static func add(_ categories: [ImportedCategory], to file: URL) throws {
        guard !categories.isEmpty else { return }
        var existing: [String: Any] = [:]
        if let data = try? Data(contentsOf: file) {
            // Rather than write over a file it can't read.
            guard let list = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
            existing = list
        }
        var added = false
        for category in categories where existing[category.name] == nil {
            guard let options = (try? JSONSerialization.jsonObject(with: category.options)) as? [String: Any] else { continue }
            existing[category.name] = options
            added = true
        }
        guard added else { return }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: existing, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: file, options: .atomic)
    }
}
