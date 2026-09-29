import Darwin
import Foundation
import Observation

/// Starts, supervises and stops the bundled qbittorrent-nox process.
///
/// The engine runs as a child of OrbTorrent: it starts with the app, is restarted if
/// it crashes, and is shut down cleanly (saving resume data) when OrbTorrent quits.
@MainActor
@Observable
final class EngineController {
    enum Status: Equatable {
        case stopped
        case starting
        case running
        case failed(String)
    }

    enum EngineError: LocalizedError {
        case missingExecutable
        case exited(String)
        case timedOut

        var errorDescription: String? {
            switch self {
            case .missingExecutable:
                "OrbTorrent's download engine is missing from the app bundle. Reinstall OrbTorrent."
            case .exited(let detail):
                detail.isEmpty ? "The download engine quit while starting." : "The download engine quit while starting:\n\(detail)"
            case .timedOut:
                "The download engine took too long to start."
            }
        }
    }

    private(set) var status: Status = .stopped
    private(set) var version: String?
    private(set) var buildInfo: BuildInfo?
    let client: QBittorrentClient

    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var crashTimes: [Date] = []
    @ObservationIgnored private var credentials: EngineCredentials
    /// The only network interface the engine may use from the moment it
    /// starts, or empty for any.
    @ObservationIgnored var networkInterface: () -> String = { "" }
    /// Called each time the engine has started, including when it starts
    /// again by itself after stopping unexpectedly.
    @ObservationIgnored var didStart: (() async -> Void)?

    var isRunning: Bool { status == .running }

    init() {
        // Read-only here; `start()` creates credentials and validates the port.
        let credentials = EngineCredentials.loadSaved()
            ?? EngineCredentials(port: 58_080, username: "orbtorrent", password: UUID().uuidString)
        self.credentials = credentials
        client = QBittorrentClient(endpoint: credentials.endpoint)
    }

    // MARK: Lifecycle

    func start() async {
        switch status {
        case .starting, .running: return
        case .stopped, .failed: break
        }
        status = .starting
        do {
            guard let executable = EnginePaths.executable else { throw EngineError.missingExecutable }
            await terminateOrphanedEngine()
            credentials = try EngineCredentials.loadOrCreate()
            await client.update(endpoint: credentials.endpoint)
            try EngineConfiguration.prepare(for: credentials, networkInterface: networkInterface())
            let process = try launch(executable)
            try await waitUntilReady(process)
            version = try? await client.appVersion()
            buildInfo = try? await client.buildInfo()
            status = .running
            await didStart?()
        } catch {
            if let process, process.isRunning { process.terminate() }
            process = nil
            status = .failed(error.localizedDescription)
        }
    }

    /// Asks the engine to save its state and exit, escalating if it doesn't.
    func stop() async {
        guard let process, process.isRunning else {
            self.process = nil
            status = .stopped
            return
        }
        self.process = nil // Mark the exit as intentional before it happens.
        try? await client.shutdown()
        if !(await waitForExit(process, timeout: .seconds(20))) {
            process.terminate()
            if !(await waitForExit(process, timeout: .seconds(5))) {
                kill(process.processIdentifier, SIGKILL)
            }
        }
        try? FileManager.default.removeItem(at: EnginePaths.pidFile)
        status = .stopped
    }

    func restart() async {
        await stop()
        crashTimes.removeAll()
        await start()
    }

    /// Changes where the engine listens, its network interface or port, and
    /// starts its DHT over. The engine doesn't bootstrap the DHT on listening
    /// sockets made while it runs, so it would otherwise find no peers through
    /// the DHT until it next starts.
    func changeListening(_ values: [String: PreferenceValue]) async throws {
        try await client.setPreferences(values)
        guard (try? await client.preferences())?.dht == true else { return }
        try await client.setPreferences(["dht": .bool(false)])
        try await client.setPreferences(["dht": .bool(true)])
    }

    /// The last lines the engine printed, for error reports.
    func recentConsoleOutput(lines: Int = 12) -> String {
        guard let text = try? String(contentsOf: EnginePaths.consoleLog, encoding: .utf8) else { return "" }
        return text.split(separator: "\n", omittingEmptySubsequences: true).suffix(lines).joined(separator: "\n")
    }

    // MARK: Process management

    private func launch(_ executable: URL) throws -> Process {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: EnginePaths.support, withIntermediateDirectories: true)
        fileManager.createFile(atPath: EnginePaths.consoleLog.path, contents: nil)
        let console = try FileHandle(forWritingTo: EnginePaths.consoleLog)

        let process = Process()
        process.executableURL = executable
        process.arguments = ["--profile=\(EnginePaths.profile.path)", "--confirm-legal-notice"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = console
        process.standardError = console
        process.terminationHandler = { [weak self] exited in
            let pid = exited.processIdentifier
            let code = exited.terminationStatus
            Task { @MainActor in self?.engineDidExit(pid: pid, code: code) }
        }
        try process.run()
        self.process = process
        try? String(process.processIdentifier).write(to: EnginePaths.pidFile, atomically: true, encoding: .utf8)
        return process
    }

    private func waitUntilReady(_ process: Process) async throws {
        let deadline = ContinuousClock.now + .seconds(45)
        while ContinuousClock.now < deadline {
            guard process.isRunning else {
                throw EngineError.exited(recentConsoleOutput())
            }
            do {
                try await client.login()
                return
            } catch APIError.unreachable {
                try await Task.sleep(for: .milliseconds(250))
            } catch let error as URLError where error.code == .badServerResponse {
                try await Task.sleep(for: .milliseconds(250))
            }
        }
        throw EngineError.timedOut
    }

    private func engineDidExit(pid: Int32, code: Int32) {
        // Ignore exits we asked for, and stale notifications from older processes.
        guard let process, process.processIdentifier == pid else { return }
        self.process = nil
        try? FileManager.default.removeItem(at: EnginePaths.pidFile)

        let now = Date()
        crashTimes = crashTimes.filter { now.timeIntervalSince($0) < 120 } + [now]
        guard crashTimes.count <= 3 else {
            let output = recentConsoleOutput()
            status = .failed("The download engine keeps stopping (exit code \(code)).\(output.isEmpty ? "" : "\n\(output)")")
            return
        }
        status = .stopped
        Task {
            try? await Task.sleep(for: .seconds(2))
            await start()
        }
    }

    private func waitForExit(_ process: Process, timeout: Duration) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while process.isRunning, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        return !process.isRunning
    }

    /// Stops an engine left running by a previous OrbTorrent session that crashed.
    private func terminateOrphanedEngine() async {
        guard let text = try? String(contentsOf: EnginePaths.pidFile, encoding: .utf8),
              let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              pid > 1,
              Self.executablePath(of: pid)?.hasSuffix("/qbittorrent-nox") == true
        else {
            try? FileManager.default.removeItem(at: EnginePaths.pidFile)
            return
        }
        kill(pid, SIGTERM)
        let deadline = ContinuousClock.now + .seconds(15)
        while kill(pid, 0) == 0, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(200))
        }
        if kill(pid, 0) == 0 { kill(pid, SIGKILL) }
        try? FileManager.default.removeItem(at: EnginePaths.pidFile)
    }

    private static func executablePath(of pid: Int32) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        let bytes = buffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
