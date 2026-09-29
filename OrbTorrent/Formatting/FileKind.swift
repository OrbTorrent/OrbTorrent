import Foundation

/// A coarse file category used to pick icons.
enum FileKind: Sendable {
    case video, audio, image, archive, document, disk, subtitle, application, other, folder

    init(path: String) {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "mkv", "mp4", "m4v", "mov", "avi", "wmv", "webm", "ts", "m2ts", "mpg", "mpeg", "flv":
            self = .video
        case "mp3", "flac", "aac", "m4a", "wav", "ogg", "opus", "alac", "aiff", "wma":
            self = .audio
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff", "bmp", "raw":
            self = .image
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "zst":
            self = .archive
        case "pdf", "epub", "txt", "nfo", "md", "doc", "docx", "rtf", "mobi", "azw3", "cbz", "cbr":
            self = .document
        case "iso", "dmg", "img", "bin", "cue":
            self = .disk
        case "srt", "ass", "ssa", "sub", "idx", "vtt":
            self = .subtitle
        case "app", "pkg", "exe", "msi", "apk", "deb", "rpm":
            self = .application
        default:
            self = .other
        }
    }

    /// Picks the kind that best describes a whole torrent from its name
    /// (single-file torrents) or falls back to a generic download icon.
    init(torrentName name: String) {
        let kind = FileKind(path: name)
        self = kind == .other ? .folder : kind
    }

    var symbol: String {
        switch self {
        case .video: "film"
        case .audio: "music.note"
        case .image: "photo"
        case .archive: "doc.zipper"
        case .document: "doc.text"
        case .disk: "opticaldiscdrive"
        case .subtitle: "captions.bubble"
        case .application: "app.dashed"
        case .other: "doc"
        case .folder: "folder"
        }
    }
}
