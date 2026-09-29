import Foundation

/// File locations used by the bundled engine.
enum EnginePaths {
    /// `~/Library/Application Support/OrbTorrent`, or `OrbTorrent Dev` for
    /// OrbTorrent Dev, which keeps its own library.
    static var support: URL {
        URL.applicationSupportDirectory.appending(path: AppIdentity.name, directoryHint: .isDirectory)
    }

    /// Passed to qbittorrent-nox as `--profile`. qBittorrent nests its own
    /// `qBittorrent/{config,data,cache}` folders inside it.
    static var profile: URL { support.appending(path: "Engine", directoryHint: .isDirectory) }

    static var configDirectory: URL { profile.appending(path: "qBittorrent/config", directoryHint: .isDirectory) }
    static var configFile: URL { configDirectory.appending(path: "qBittorrent.ini") }
    static var categoriesFile: URL { configDirectory.appending(path: "categories.json") }
    static var dataDirectory: URL { profile.appending(path: "qBittorrent/data", directoryHint: .isDirectory) }
    static var resumeDirectory: URL { dataDirectory.appending(path: "BT_backup", directoryHint: .isDirectory) }
    static var engineLog: URL { dataDirectory.appending(path: "logs/qbittorrent.log") }

    /// The engine's stdout and stderr.
    static var consoleLog: URL { support.appending(path: "engine-console.log") }
    static var credentials: URL { support.appending(path: "engine-credentials.json") }
    static var pidFile: URL { support.appending(path: "engine.pid") }

    /// The qbittorrent-nox executable embedded in `OrbTorrent.app/Contents/MacOS`.
    static var executable: URL? {
        Bundle.main.url(forAuxiliaryExecutable: "qbittorrent-nox")
    }
}
