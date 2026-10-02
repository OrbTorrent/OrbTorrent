import CoreServices
import Darwin
import Foundation

/// Adds files next to a finished download's files, for `files.save`. Each one
/// is named after a file of the download, in the same folder, and is of a kind
/// that can't run: subtitles, text, images or checksums. It never replaces a
/// file, except one the same hook added to the same download before.
actor ExtensionFileAdder {
    static let maximumFile = 10 << 20
    static let maximumRun = 50 << 20
    static let maximumFiles = 200

    /// What a file can be, by its extension.
    static let kinds: [(title: String, extensions: [String])] = [
        ("subtitles", ["srt", "ass", "ssa", "vtt", "sub", "idx", "sup", "smi", "lrc"]),
        ("text", ["txt", "nfo", "md", "json", "xml", "csv", "cue"]),
        ("images", ["jpg", "jpeg", "png", "webp", "gif", "heic"]),
        ("checksums", ["sfv", "md5", "sha1", "sha256"]),
    ]
    static let allowedExtensions = Set(kinds.flatMap(\.extensions))

    struct Saved: Sendable, Equatable {
        /// Relative to the download's folder, like a download file's path.
        let path: String
        let size: Int
    }

    private let folder: URL?
    private let files: [Int: URL]
    private let allowed: Bool
    /// Files this hook added to this download before, which it may replace.
    private let replaceable: Set<String>
    /// The files added in this run, in order.
    private(set) var added: [String] = []
    private var bytes = 0

    /// - Parameters:
    ///   - folder: the folder the download is saved in.
    ///   - files: its finished files by index.
    ///   - allowed: whether the extension has `"files": "add"`.
    init(folder: URL?, files: [Int: URL], allowed: Bool, replaceable: Set<String> = []) {
        self.folder = folder
        self.files = files
        self.allowed = allowed
        self.replaceable = replaceable
    }

    /// For a run that can't add files, such as `verify`.
    static var none: ExtensionFileAdder { ExtensionFileAdder(folder: nil, files: [:], allowed: false) }

    func save(file index: Int?, suffix: String?, contents: Data?) throws -> Saved {
        guard allowed else {
            throw ExtensionRefusal(message: "Adding files isn't allowed. Add \"files\": \"add\" to permissions in package.json, or [\"contents\", \"add\"] to read files too.")
        }
        guard let index else { throw ExtensionRefusal(message: "Pass a file from download.files.") }
        guard let source = files[index], let folder else {
            throw ExtensionRefusal(message: "File \(index) isn't available: it isn't downloaded yet, or it isn't part of this download.")
        }
        guard let suffix, Self.isSuffix(suffix) else {
            throw ExtensionRefusal(message: "“\(suffix ?? "")” can't be added to a file's name. A suffix starts with “.”, “-”, “_” or a space, and ends with an extension, such as “.en.srt”.")
        }
        let kind = Self.lastExtension(of: suffix).lowercased()
        guard Self.allowedExtensions.contains(kind) else {
            throw ExtensionRefusal(message: "Extensions can't add .\(kind) files, only \(Self.describeKinds()).")
        }
        let name = source.deletingPathExtension().lastPathComponent + suffix
        guard name.utf8.count <= 255 else {
            throw ExtensionRefusal(message: "“\(name)” is too long for a file name.")
        }
        guard let contents else {
            throw ExtensionRefusal(message: "files.save needs the file's contents: text, or bytes as a Uint8Array.")
        }
        guard contents.count <= Self.maximumFile else {
            throw ExtensionRefusal(message: "“\(name)” is larger than 10 MB, the most an extension can add in one file.")
        }
        guard added.count < Self.maximumFiles else {
            throw ExtensionRefusal(message: "This run has already added \(Self.maximumFiles) files, the most an extension can add in one run.")
        }
        guard bytes + contents.count <= Self.maximumRun else {
            throw ExtensionRefusal(message: "This run has already added nearly 50 MB, the most an extension can add in one run.")
        }

        // The file's folder, wherever links lead, must be inside the download's.
        let parent = source.deletingLastPathComponent()
        let realParent = parent.resolvingSymlinksInPath().standardizedFileURL.path
        let realFolder = folder.resolvingSymlinksInPath().standardizedFileURL.path
        guard realParent == realFolder || realParent.hasPrefix(realFolder.hasSuffix("/") ? realFolder : realFolder + "/") else {
            throw ExtensionRefusal(message: "File \(index) isn't in the download's folder, so nothing can be added next to it.")
        }
        let target = parent.appending(path: name)
        let path = Self.relativePath(of: target, in: folder)

        var status = stat()
        if lstat(target.path, &status) == 0 {
            guard replaceable.contains(path), status.st_mode & S_IFMT == S_IFREG else {
                throw ExtensionRefusal(message: "“\(name)” already exists. An extension can't replace a file it didn't add.")
            }
            try Self.replace(target, with: contents)
        } else {
            try Self.create(target, with: contents)
        }
        Self.markDownloaded(target)
        if !added.contains(path) { added.append(path) }
        bytes += contents.count
        return Saved(path: path, size: contents.count)
    }

    /// Starts with a separator and ends with an extension, with nothing that
    /// could lead to another folder: “.en.srt”, “-poster.jpg”.
    static func isSuffix(_ text: String) -> Bool {
        guard text.count <= 64, let first = text.first, ".-_ ".contains(first) else { return false }
        guard !text.unicodeScalars.contains(where: { $0 == "/" || $0 == "\\" || $0 == ":" || $0.properties.generalCategory == .control }) else {
            return false
        }
        let pathExtension = lastExtension(of: text)
        return !pathExtension.isEmpty && pathExtension.count <= 10
            && pathExtension.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// What follows the last dot: “srt” for “.en.srt”, and for “.srt” too.
    static func lastExtension(of text: String) -> String {
        text.lastIndex(of: ".").map { String(text[text.index(after: $0)...]) } ?? ""
    }

    /// The same words in every language the Mac uses, as in `orb test`.
    static func describeKinds() -> String {
        "subtitles, text, images and checksums: " + kinds.flatMap(\.extensions).map { ".\($0)" }.joined(separator: ", ")
    }

    /// By the paths alone: `standardizedFileURL` drops a leading /private
    /// only from paths that exist, which a new file doesn't yet.
    static func relativePath(of file: URL, in folder: URL) -> String {
        let base = folder.standardized.path
        let path = file.standardized.path
        let prefix = base.hasSuffix("/") ? base : base + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : file.lastPathComponent
    }

    // MARK: Writing

    /// Writes a new file, failing if anything is already there, even a link.
    private static func create(_ url: URL, with data: Data) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else {
            if errno == EEXIST {
                throw ExtensionRefusal(message: "“\(url.lastPathComponent)” already exists. An extension can't replace a file it didn't add.")
            }
            throw failure(url, errno)
        }
        do {
            try write(data, to: descriptor)
            fchmod(descriptor, 0o644)
            close(descriptor)
        } catch {
            close(descriptor)
            unlink(url.path)
            throw error
        }
    }

    /// Replaces a file the hook added before: a new file beside it, renamed over it.
    private static func replace(_ url: URL, with data: Data) throws {
        let temporary = url.deletingLastPathComponent().appending(path: ".\(url.lastPathComponent).\(UUID().uuidString).orbtorrent")
        try create(temporary, with: data)
        guard rename(temporary.path, url.path) == 0 else {
            let code = errno
            unlink(temporary.path)
            throw failure(url, code)
        }
    }

    private static func write(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            var offset = 0
            while offset < buffer.count {
                let written = Darwin.write(descriptor, base + offset, buffer.count - offset)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw failure(nil, errno)
                }
                offset += written
            }
        }
    }

    private static func failure(_ url: URL?, _ code: Int32) -> ExtensionRefusal {
        let reason = String(cString: strerror(code))
        return ExtensionRefusal(message: url.map { "“\($0.lastPathComponent)” couldn't be saved: \(reason)." } ?? "The file couldn't be saved: \(reason).")
    }

    /// Marks it as downloaded from the internet, as browsers do, so macOS
    /// checks it like any other download.
    private static func markDownloaded(_ url: URL) {
        var values = URLResourceValues()
        values.quarantineProperties = [
            kLSQuarantineAgentNameKey as String: AppIdentity.name,
            kLSQuarantineTypeKey as String: kLSQuarantineTypeOtherDownload as String,
        ]
        var url = url
        try? url.setResourceValues(values)
    }
}
