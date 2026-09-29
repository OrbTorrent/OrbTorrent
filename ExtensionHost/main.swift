import Darwin
import Foundation
import JavaScriptCore

// orb-extension-host runs one extension entry point in JavaScriptCore and
// exits. It's sandboxed with no access to files or the network: everything an
// extension asks for goes to OrbTorrent over stdout, which checks it against
// the extension's permissions and answers over stdin. Messages are JSON
// objects, one per line.
//
// OrbTorrent → helper:
//   {"type":"run","script":"…","function":"default","arguments":[…],"context":{…}}
//   {"type":"reply","id":1,"ok":true,"value":…}   or   {"type":"reply","id":1,"ok":false,"error":"…"}
// Helper → OrbTorrent:
//   {"type":"ready"}
//   {"type":"log","level":"log","message":"…"}
//   {"type":"call","id":1,"method":"fetch","params":{…}}
//   {"type":"done","ok":true,"value":…}   or   {"type":"done","ok":false,"error":{"message":"…","stack":"…"}}

@MainActor
func send(_ message: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.fragmentsAllowed]) else { return }
    FileHandle.standardOutput.write(data + Data([0x0A]))
}

/// Parses JSON text into a Foundation value for `send`.
func jsonObject(_ text: String) -> Any {
    (try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])) ?? NSNull()
}

@MainActor
final class Runtime {
    private let context: JSContext
    private var timers: [Int: DispatchWorkItem] = [:]
    private var hasFinished = false

    init() {
        context = JSContext()!
        context.name = "OrbTorrent extension"
        context.exceptionHandler = { _, exception in
            MainActor.assumeIsolated {
                let message = exception?.objectForKeyedSubscript("message")?.toString() ?? exception?.toString() ?? "Unknown error"
                let stack = exception?.objectForKeyedSubscript("stack")?.toString() ?? ""
                send(["type": "log", "level": "error", "message": "Uncaught \(message)\n\(stack)"])
            }
        }
        install()
    }

    private func install() {
        let call: @convention(block) (Int, String, String) -> Void = { id, method, params in
            MainActor.assumeIsolated {
                send(["type": "call", "id": id, "method": method, "params": jsonObject(params)])
            }
        }
        let log: @convention(block) (String, String) -> Void = { level, message in
            MainActor.assumeIsolated { send(["type": "log", "level": level, "message": message]) }
        }
        let timer: @convention(block) (Int, Double) -> Void = { [unowned self] id, milliseconds in
            MainActor.assumeIsolated { schedule(id, after: milliseconds) }
        }
        let cancelTimer: @convention(block) (Int) -> Void = { [unowned self] id in
            MainActor.assumeIsolated { _ = timers.removeValue(forKey: id).map { $0.cancel() } }
        }
        let done: @convention(block) (Bool, String) -> Void = { [unowned self] ok, json in
            MainActor.assumeIsolated { finish(ok: ok, json: json) }
        }
        let parseURL: @convention(block) (String, JSValue) -> String? = { input, base in
            Self.parseURL(input, base: base.isString ? base.toString() : nil)
        }
        let random: @convention(block) (Int) -> [UInt8] = { count in
            var bytes = [UInt8](repeating: 0, count: max(0, min(count, 65_536)))
            arc4random_buf(&bytes, bytes.count)
            return bytes
        }
        context.setObject(call, forKeyedSubscript: "__orbNativeCall" as NSString)
        context.setObject(log, forKeyedSubscript: "__orbNativeLog" as NSString)
        context.setObject(timer, forKeyedSubscript: "__orbNativeTimer" as NSString)
        context.setObject(cancelTimer, forKeyedSubscript: "__orbNativeCancelTimer" as NSString)
        context.setObject(done, forKeyedSubscript: "__orbNativeDone" as NSString)
        context.setObject(parseURL, forKeyedSubscript: "__orbNativeParseURL" as NSString)
        context.setObject(random, forKeyedSubscript: "__orbNativeRandom" as NSString)
        context.evaluateScript(Bootstrap.source, withSourceURL: URL(string: "orbtorrent://bootstrap.js"))
    }

    private func schedule(_ id: Int, after milliseconds: Double) {
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.timers[id] = nil
                self.context.objectForKeyedSubscript("__orbFireTimer").call(withArguments: [id])
            }
        }
        timers[id] = item
        let delay = max(0, milliseconds.isFinite ? milliseconds : 0) / 1_000
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func run(_ message: [String: Any]) {
        guard let script = message["script"] as? String else {
            return finish(ok: false, json: #"{"message":"The run message has no script."}"#)
        }
        let function = message["function"] as? String ?? "default"
        let arguments = message["arguments"] ?? []
        let context = message["context"] ?? [:]
        guard let argumentsJSON = Self.jsonText(arguments), let contextJSON = Self.jsonText(context) else {
            return finish(ok: false, json: #"{"message":"The run message couldn't be read."}"#)
        }
        self.context.evaluateScript(script, withSourceURL: URL(string: "orbtorrent://extension.js"))
        self.context.objectForKeyedSubscript("__orbStart").call(withArguments: [function, argumentsJSON, contextJSON])
    }

    func reply(_ message: [String: Any]) {
        guard let id = message["id"] as? Int else { return }
        let ok = message["ok"] as? Bool ?? false
        let value = ok ? (message["value"] ?? NSNull()) : (message["error"] ?? "Unknown error")
        let json = Self.jsonText(value) ?? "null"
        context.objectForKeyedSubscript("__orbReply").call(withArguments: [id, ok, json])
    }

    private func finish(ok: Bool, json: String) {
        guard !hasFinished else { return }
        hasFinished = true
        if ok {
            send(["type": "done", "ok": true, "value": jsonObject(json)])
        } else {
            send(["type": "done", "ok": false, "error": jsonObject(json)])
        }
        exit(0)
    }

    private static func jsonText(_ value: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// The parts of a URL, for the `URL` class, or nil if it isn't one.
    private static func parseURL(_ input: String, base: String?) -> String? {
        let url: URL?
        if let base, let baseURL = URL(string: base), baseURL.scheme != nil {
            url = URL(string: input, relativeTo: baseURL)?.absoluteURL
        } else {
            url = URL(string: input)
        }
        guard let url, let scheme = url.scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else { return nil }
        let port = components.port.map(String.init) ?? ""
        let host = components.percentEncodedHost ?? ""
        let parts: [String: Any] = [
            "protocol": scheme.lowercased() + ":",
            "username": components.percentEncodedUser ?? "",
            "password": components.percentEncodedPassword ?? "",
            "hostname": host,
            "port": port,
            "pathname": components.percentEncodedPath.isEmpty && !host.isEmpty ? "/" : components.percentEncodedPath,
            "search": components.percentEncodedQuery.map { $0.isEmpty ? "" : "?" + $0 } ?? "",
            "hash": components.percentEncodedFragment.map { $0.isEmpty ? "" : "#" + $0 } ?? "",
        ]
        return jsonText(parts)
    }
}

@MainActor
func start() {
    let runtime = Runtime()
    send(["type": "ready"])
    Thread.detachNewThread {
        while let line = readLine(strippingNewline: true) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  let type = object["type"] as? String else { continue }
            nonisolated(unsafe) let message = object
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    switch type {
                    case "run": runtime.run(message)
                    case "reply": runtime.reply(message)
                    default: break
                    }
                }
            }
        }
        // OrbTorrent closed the pipe: it no longer wants the result.
        exit(0)
    }
}

MainActor.assumeIsolated { start() }
dispatchMain()
