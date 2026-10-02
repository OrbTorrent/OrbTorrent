import Darwin
import Foundation

/// "When a download finishes, run": the user's own program or script, chosen
/// in Settings. It runs for each download that finishes, once that download's
/// checks after finishing have run, and not if one of them failed.
///
/// It runs as the user, like any program they open, so only a person in the
/// Settings window can choose it: never an extension, `orb`, or the engine,
/// whose own way of running programs stays off (EngineConfiguration). It's
/// started directly, without a shell, so a download's name can't become part
/// of a command. Programs run one at a time, in the order downloads finish.
@MainActor
final class FinishedProgram {
    /// A program still running after this is stopped.
    static let timeLimit: Duration = .seconds(60 * 60)
    nonisolated static var log: URL { EnginePaths.support.appending(path: "Logs/When a Download Finishes.log") }
    private nonisolated static let logLimit = 1 << 20

    private let settings: AppSettings
    private let extensions: Extensions
    /// Where its runs are logged; another file in tests.
    private let log: URL
    private var knownComplete: [String: Bool]?
    /// The last program queued, which the next waits for.
    private var tail: Task<Void, Never>?

    init(settings: AppSettings, extensions: Extensions, log: URL = FinishedProgram.log) {
        self.settings = settings
        self.extensions = extensions
        self.log = log
    }

    /// Called with each refresh of the library, after extensions see it.
    func observe(_ torrents: [Torrent]) {
        let complete = Dictionary(torrents.map { ($0.hash, $0.isComplete) }, uniquingKeysWith: { $1 })
        defer { knownComplete = complete }
        // The first look, at launch, only notes what's finished already.
        guard let knownComplete, settings.finishedProgram != nil else { return }
        for torrent in torrents where torrent.isComplete && torrent.finishedJustNow() {
            switch knownComplete[torrent.hash] {
            case false?, nil: queue(torrent)
            case true?: break
            }
        }
    }

    private func queue(_ torrent: Torrent) {
        Task {
            let checks = await extensions.afterFinishChecks(for: torrent.hash)
            let previous = tail
            tail = Task {
                await previous?.value
                await run(for: torrent, after: checks)
            }
        }
    }

    private func run(for torrent: Torrent, after checks: [CheckRecord]) async {
        // Chosen when it finished, but it may have been taken out since.
        guard let path = settings.finishedProgram else { return }
        if let failed = checks.first(where: { $0.status == .failed }) {
            return Self.append("Didn't run for “\(torrent.name)”: \(failed.extensionTitle) found a problem. \(failed.summary)", to: log)
        }
        guard let executable = Self.executable(for: URL(fileURLWithPath: path)) else {
            return Self.append("Couldn't run \(path) for “\(torrent.name)”: it's missing, or it isn't a program that can run.", to: log)
        }
        Self.append("Running \(path) for “\(torrent.name)”", to: log)
        let status = await Self.launch(executable, with: Self.environment(for: torrent),
                                       argument: torrent.contentPath, in: torrent.savePath, log: log)
        Self.append(status, to: log)
    }

    /// What the program gets about the download, besides its file or folder as `$1`.
    nonisolated static func environment(for torrent: Torrent) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        // A Mac app starts with a short PATH; add Homebrew's, where command-line tools usually are.
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        environment["ORB_NAME"] = torrent.name
        environment["ORB_HASH"] = torrent.hash
        environment["ORB_PATH"] = torrent.contentPath
        environment["ORB_FOLDER"] = torrent.savePath
        environment["ORB_SIZE"] = String(torrent.size)
        environment["ORB_PRIVATE"] = (torrent.isPrivate ?? false) ? "true" : "false"
        return environment
    }

    /// The file to run: the program itself, or the one inside an app.
    nonisolated static func executable(for url: URL) -> URL? {
        if url.pathExtension.lowercased() == "app" {
            return Bundle(url: url)?.executableURL
        }
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder), !isFolder.boolValue,
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }

    /// Runs it to the end, or until the time limit, and says how it ended.
    nonisolated static func launch(_ executable: URL, with environment: [String: String],
                                   argument: String, in folder: String, log: URL = FinishedProgram.log) async -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = [argument]
        process.environment = environment
        if !folder.isEmpty { process.currentDirectoryURL = URL(fileURLWithPath: folder, isDirectory: true) }
        process.standardInput = FileHandle.nullDevice
        let output = openLog(log)
        process.standardOutput = output ?? FileHandle.nullDevice
        process.standardError = output ?? FileHandle.nullDevice
        defer { try? output?.close() }

        let ended = AsyncStream<Void> { continuation in
            process.terminationHandler = { _ in continuation.finish() }
        }
        do {
            try process.run()
        } catch {
            return "Couldn't start it: \(error.localizedDescription)"
        }
        // Stopped at the time limit: asked to quit, then made to.
        let pid = process.processIdentifier
        let watchdog = Task { () -> Bool in
            guard (try? await Task.sleep(for: timeLimit)) != nil else { return false }
            kill(pid, SIGTERM)
            if (try? await Task.sleep(for: .seconds(5))) != nil { kill(pid, SIGKILL) }
            return true
        }
        for await _ in ended {}
        watchdog.cancel()
        if await watchdog.value { return "Stopped: it ran for over an hour." }
        return process.terminationReason == .exit
            ? "Finished with exit code \(process.terminationStatus)."
            : "Ended by signal \(process.terminationStatus)."
    }

    // MARK: The log

    /// Adds a line to the log, with the time.
    nonisolated static func append(_ line: String, to log: URL = FinishedProgram.log) {
        guard let handle = openLog(log) else { return }
        defer { try? handle.close() }
        try? handle.write(contentsOf: Data("\(Date.now.formatted(.iso8601)) \(line)\n".utf8))
    }

    /// The log, open for adding to. One older file is kept once it passes 1 MB.
    private nonisolated static func openLog(_ log: URL) -> FileHandle? {
        let manager = FileManager.default
        try? manager.createDirectory(at: log.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let size = (try? manager.attributesOfItem(atPath: log.path))?[.size] as? Int, size > logLimit {
            let older = log.appendingPathExtension("1")
            try? manager.removeItem(at: older)
            try? manager.moveItem(at: log, to: older)
        }
        if !manager.fileExists(atPath: log.path) { manager.createFile(atPath: log.path, contents: nil) }
        guard let handle = try? FileHandle(forWritingTo: log) else { return nil }
        _ = try? handle.seekToEnd()
        return handle
    }
}
