import Darwin
import Foundation

/// How long, and with how much, one run of an extension may go on.
struct ExtensionLimits: Sendable, Equatable {
    /// From start to finish, waiting included.
    var time: Duration
    /// Time spent computing. Waiting for the network or a timer doesn't count.
    var cpuTime: Duration
    var memory: UInt64

    /// A check that holds up a download has to be quick.
    static let beforeStart = ExtensionLimits(time: .seconds(15), cpuTime: .seconds(10), memory: 512 << 20)
    /// Long enough for a scan that paces itself for a service's rate limit.
    static let afterFinish = ExtensionLimits(time: .seconds(6 * 60 * 60), cpuTime: .seconds(120), memory: 512 << 20)
    static let verify = ExtensionLimits(time: .seconds(15), cpuTime: .seconds(10), memory: 512 << 20)
}

/// How a run ended.
enum ExtensionOutcome: Sendable, Equatable {
    enum StopReason: Sendable, Equatable {
        case time, cpuTime, memory, cancelled
    }

    /// The entry point returned this value.
    case returned(JSONValue)
    /// It threw an error, or its promise was rejected.
    case threw(message: String, stack: String)
    /// OrbTorrent stopped it.
    case stopped(StopReason)
    /// The helper quit or crashed without a result.
    case crashed(String)
    case couldNotStart(String)
}

/// What an extension runs, and with what.
struct ExtensionJob: Sendable {
    /// The bundled script, which sets `__orbExtension`.
    let script: String
    /// The export to call: `default` for a hook.
    var function = "default"
    let arguments: [JSONValue]
    /// Available to the extension as `__orb.context`: its settings and environment.
    let context: JSONValue
    let limits: ExtensionLimits
}

/// Answers what an extension asks OrbTorrent for, after checking it's allowed.
protocol ExtensionCallHandler: Sendable {
    func handle(method: String, params: JSONValue) async throws -> JSONValue
    func log(level: String, message: String)
}

/// Runs extensions, each in a fresh sandboxed `orb-extension-host` process.
struct ExtensionRunner: Sendable {
    let helper: URL

    /// The helper embedded in `OrbTorrent.app/Contents/MacOS`.
    static var bundled: ExtensionRunner? {
        Bundle.main.url(forAuxiliaryExecutable: "orb-extension-host").map(ExtensionRunner.init(helper:))
    }

    /// Runs a job to the end. Cancelling the task stops the helper.
    func run(_ job: ExtensionJob, handler: some ExtensionCallHandler) async -> ExtensionOutcome {
        let session = HelperSession(helper: helper, handler: handler)
        do {
            try session.launch()
        } catch {
            return .couldNotStart(error.localizedDescription)
        }
        session.send([
            "type": "run", "script": job.script, "function": job.function,
            "arguments": job.arguments.map(\.any), "context": job.context.any,
        ])
        await withTaskCancellationHandler {
            await session.watch(limits: job.limits)
        } onCancel: {
            session.stop(.cancelled)
        }
        return session.outcome()
    }
}

/// One helper process and its conversation with OrbTorrent.
private final class HelperSession: @unchecked Sendable {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let handler: any ExtensionCallHandler
    private let lock = NSLock()
    private var result: ExtensionOutcome?
    private var stopReason: ExtensionOutcome.StopReason?
    private var hasExited = false
    private var hasReadEverything = false
    /// Calls being answered, stopped with the helper.
    private var calls: [Int: Task<Void, Never>] = [:]

    /// The most a helper may print before it's stopped, against runaway logging.
    private static let maximumOutput = 64 << 20
    private static let maximumLogLength = 10_000

    init(helper: URL, handler: any ExtensionCallHandler) {
        self.handler = handler
        process.executableURL = helper
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
    }

    func launch() throws {
        process.terminationHandler = { [weak self] _ in self?.didExit() }
        try process.run()
        let reader = output.fileHandleForReading
        Thread.detachNewThread { [self] in
            var buffer = Data()
            var total = 0
            while true {
                let chunk = reader.availableData
                if chunk.isEmpty { break }
                total += chunk.count
                if total > Self.maximumOutput {
                    stop(.memory)
                    break
                }
                buffer.append(chunk)
                while let newline = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[buffer.startIndex..<newline]
                    buffer.removeSubrange(buffer.startIndex...newline)
                    if let message = try? JSONValue(data: Data(line)) { receive(message) }
                }
            }
            lock.withLock { hasReadEverything = true }
        }
    }

    private func receive(_ message: JSONValue) {
        switch message["type"]?.string {
        case "log":
            let text = message["message"]?.string ?? ""
            handler.log(level: message["level"]?.string ?? "log", message: String(text.prefix(Self.maximumLogLength)))
        case "call":
            guard let id = message["id"]?.int, let method = message["method"]?.string else { return }
            let params = message["params"] ?? .null
            let handler = handler
            let task = Task { [weak self] in
                do {
                    let value = try await handler.handle(method: method, params: params)
                    self?.send(["type": "reply", "id": id, "ok": true, "value": value.any])
                } catch {
                    self?.send(["type": "reply", "id": id, "ok": false, "error": error.localizedDescription])
                }
                self?.lock.withLock { _ = self?.calls.removeValue(forKey: id) }
            }
            let exited = lock.withLock {
                if !hasExited { calls[id] = task }
                return hasExited
            }
            if exited { task.cancel() }
        case "done":
            let outcome: ExtensionOutcome
            if message["ok"]?.bool == true {
                outcome = .returned(message["value"] ?? .null)
            } else {
                let error = message["error"]
                outcome = .threw(message: error?["message"]?.string ?? "The extension failed.",
                                 stack: error?["stack"]?.string ?? "")
            }
            lock.withLock { if result == nil { result = outcome } }
        default:
            break
        }
    }

    func send(_ message: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.fragmentsAllowed]) else { return }
        lock.withLock {
            guard !hasExited else { return }
            try? input.fileHandleForWriting.write(contentsOf: data + Data([0x0A]))
        }
    }

    /// Checks the helper against its limits until it exits.
    func watch(limits: ExtensionLimits) async {
        let started = ContinuousClock.now
        let pid = process.processIdentifier
        while !exited {
            if ContinuousClock.now - started > limits.time {
                stop(.time)
            } else if let usage = Self.usage(of: pid) {
                if usage.memory > limits.memory {
                    stop(.memory)
                } else if usage.cpuTime > limits.cpuTime {
                    stop(.cpuTime)
                }
            }
            await Self.pause(milliseconds: 20)
        }
        // Let the last messages, such as the result, arrive.
        for _ in 0..<100 where !lock.withLock({ hasReadEverything }) {
            await Self.pause(milliseconds: 20)
        }
    }

    private var exited: Bool { lock.withLock { hasExited } }

    func stop(_ reason: ExtensionOutcome.StopReason) {
        let shouldKill = lock.withLock {
            guard !hasExited, stopReason == nil, result == nil else { return false }
            stopReason = reason
            return true
        }
        if shouldKill { kill(process.processIdentifier, SIGKILL) }
    }

    private func didExit() {
        let pending = lock.withLock {
            hasExited = true
            defer { calls.removeAll() }
            return Array(calls.values)
        }
        // Nobody is waiting for these answers any more.
        pending.forEach { $0.cancel() }
    }

    /// Sleeps even when the task is cancelled, which stops the helper and
    /// leaves this waiting for it to exit.
    private static func pause(milliseconds: Int) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(milliseconds)) { continuation.resume() }
        }
    }

    func outcome() -> ExtensionOutcome {
        process.waitUntilExit()
        return lock.withLock {
            if let result { return result }
            if let stopReason { return .stopped(stopReason) }
            if process.terminationReason == .uncaughtSignal {
                return .crashed("The extension crashed (signal \(process.terminationStatus)).")
            }
            return .crashed("The extension quit without a result (code \(process.terminationStatus)).")
        }
    }

    /// Memory in use and CPU time so far.
    private static func usage(of pid: pid_t) -> (memory: UInt64, cpuTime: Duration)? {
        var info = rusage_info_v4()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
        }
        guard status == 0 else { return nil }
        let ticks = info.ri_user_time + info.ri_system_time
        return (info.ri_phys_footprint, .nanoseconds(Int64(clamping: ticks * UInt64(timebase.numer) / UInt64(timebase.denom))))
    }

    /// CPU times are in Mach time units, which aren't nanoseconds on Apple silicon.
    private static let timebase: mach_timebase_info_data_t = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info
    }()
}
