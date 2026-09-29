import Foundation

/// Reads the port Private Internet Access forwards, from its app's
/// command-line tool. PIA forwards the port to the same port on this Mac.
enum PIAControl {
    static let tool = "/Applications/Private Internet Access.app/Contents/MacOS/piactl"

    /// The forwarded port, or nil when PIA isn't installed, isn't connected
    /// or isn't forwarding one. Waits for the tool, so call it off the main thread.
    static func forwardedPort() -> UInt16? {
        guard FileManager.default.isExecutableFile(atPath: tool) else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["get", "portforward"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do { try process.run() } catch { return nil }
        guard finished.wait(timeout: .now() + 5) == .success else {
            process.terminate()
            return nil
        }
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        // A number, or Inactive, Attempting, Failed or Unavailable.
        return parse(text)
    }

    static func parse(_ output: String) -> UInt16? {
        UInt16(output.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0 == 0 ? nil : $0 }
    }
}
