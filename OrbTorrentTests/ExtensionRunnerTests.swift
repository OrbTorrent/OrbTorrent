import Foundation
import Testing
@testable import OrbTorrent

/// Answers calls from a script the way a test says, and keeps its logs.
final class StubHandler: ExtensionCallHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var _logs: [String] = []
    private let answer: @Sendable (String, JSONValue) async throws -> JSONValue

    init(answer: @escaping @Sendable (String, JSONValue) async throws -> JSONValue = { _, _ in .null }) {
        self.answer = answer
    }

    var logs: [String] { lock.withLock { _logs } }

    func handle(method: String, params: JSONValue) async throws -> JSONValue {
        try await answer(method, params)
    }

    func log(level: String, message: String) {
        lock.withLock { _logs.append("\(level): \(message)") }
    }
}

/// These run scripts in the real sandboxed helper inside the built app.
@Suite(.serialized)
struct ExtensionRunnerTests {
    let runner = ExtensionRunner.bundled!
    let quick = ExtensionLimits(time: .seconds(10), cpuTime: .seconds(5), memory: 256 << 20)

    func job(_ script: String, arguments: [JSONValue] = [], context: JSONValue = [:],
             limits: ExtensionLimits? = nil) -> ExtensionJob {
        ExtensionJob(script: script, arguments: arguments, context: context, limits: limits ?? quick)
    }

    @Test func runsAHookWithItsDownloadAndSettings() async {
        let script = """
        var __orbExtension = { default: async (download) => {
          await new Promise((resolve) => setTimeout(resolve, 20));
          return { status: "passed", summary: `${download.files.length} files for ${__orb.context.preferences.who}` };
        }};
        """
        let outcome = await runner.run(job(script, arguments: [["name": "Show", "files": [["path": "a.mkv"], ["path": "b.nfo"]]]],
                                           context: ["preferences": ["who": "Sam"]]), handler: StubHandler())
        #expect(outcome == .returned(["status": "passed", "summary": "2 files for Sam"]))
    }

    @Test func callsGoToOrbTorrentAndCanBeRefused() async {
        let script = """
        var __orbExtension = { default: async () => {
          const answer = await __orb.call("echo", { value: 42 });
          let refusal;
          try { await __orb.call("fetch", { url: "https://example.com" }); } catch (error) { refusal = error.message; }
          return { answer, refusal };
        }};
        """
        let handler = StubHandler { method, params in
            if method == "echo" { return params["value"] ?? .null }
            throw ExtensionRefusal(message: "Request to example.com was refused.")
        }
        let outcome = await runner.run(job(script), handler: handler)
        #expect(outcome == .returned(["answer": 42, "refusal": "Request to example.com was refused."]))
    }

    @Test func logsReachOrbTorrent() async {
        let handler = StubHandler()
        let script = #"var __orbExtension = { default: () => { console.log("found", { files: 2 }); console.warn("careful"); return null; } };"#
        _ = await runner.run(job(script), handler: handler)
        #expect(handler.logs == [#"log: found {"files":2}"#, "warn: careful"])
    }

    @Test func aThrownErrorIsReported() async {
        let script = #"var __orbExtension = { default: async () => { throw new Error("No API key"); } };"#
        guard case .threw(let message, _) = await runner.run(job(script), handler: StubHandler()) else {
            Issue.record("Expected an error")
            return
        }
        #expect(message == "No API key")
    }

    @Test func aScriptWithoutADefaultExportSaysHowToFixIt() async {
        guard case .threw(let message, _) = await runner.run(job("var __orbExtension = { other: () => 1 };"), handler: StubHandler()) else {
            Issue.record("Expected an error")
            return
        }
        #expect(message.contains("export default"))
    }

    @Test func anEndlessLoopIsStoppedForUsingTheCPU() async {
        let limits = ExtensionLimits(time: .seconds(20), cpuTime: .seconds(1), memory: 256 << 20)
        let started = ContinuousClock.now
        let outcome = await runner.run(job("var __orbExtension = { default: () => { while (true) {} } };", limits: limits),
                                       handler: StubHandler())
        #expect(outcome == .stopped(.cpuTime))
        #expect(ContinuousClock.now - started < .seconds(4))
    }

    @Test func waitingDoesntCountAsCPUTimeButTimeRunsOut() async {
        let limits = ExtensionLimits(time: .seconds(1), cpuTime: .milliseconds(500), memory: 256 << 20)
        let outcome = await runner.run(job("var __orbExtension = { default: () => new Promise(() => {}) };", limits: limits),
                                       handler: StubHandler())
        #expect(outcome == .stopped(.time))
    }

    @Test func aMemoryHogIsStopped() async {
        let limits = ExtensionLimits(time: .seconds(20), cpuTime: .seconds(20), memory: 128 << 20)
        let script = "var __orbExtension = { default: () => { const a = []; while (true) a.push(new Array(1e6).fill(Math.random())); } };"
        #expect(await runner.run(job(script, limits: limits), handler: StubHandler()) == .stopped(.memory))
    }

    @Test func cancellingStopsTheHelper() async {
        let task = Task {
            await runner.run(job("var __orbExtension = { default: () => new Promise(() => {}) };"), handler: StubHandler())
        }
        try? await Task.sleep(for: .milliseconds(300))
        task.cancel()
        #expect(await task.value == .stopped(.cancelled))
    }

    @Test func webAPIsExtensionsExpectAreThere() async {
        let script = """
        var __orbExtension = { default: () => {
          const url = new URL("https://www.virustotal.com/api/v3/files/abc?x=1");
          url.searchParams.set("y", "a b");
          const bytes = new TextEncoder().encode("héllo");
          return [url.href, url.host, bytes.length, new TextDecoder().decode(bytes), btoa("hi!"), atob("aGkh"),
                  crypto.randomUUID().length, typeof queueMicrotask, typeof structuredClone];
        }};
        """
        #expect(await runner.run(job(script), handler: StubHandler()) == .returned([
            "https://www.virustotal.com/api/v3/files/abc?x=1&y=a+b", "www.virustotal.com", 6, "héllo", "aGkh", "hi!",
            36, "function", "function",
        ]))
    }
}
