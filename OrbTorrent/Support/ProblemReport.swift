import Foundation

/// A problem report, written by the person and filled in with what helps:
/// the OrbTorrent, macOS and engine versions, the Mac, and optionally the
/// engine's recent log. It's all shown before it goes anywhere, and it goes
/// only from the person's own mail app, when they send it.
struct ProblemReport {
    /// On our domain, so where reports go can change without an update.
    static let address = "help@orbtorrent.com"
    static let logLines = 60

    var description = ""
    var includesLog = false

    /// OrbTorrent, macOS, the Mac and the engine, one per line.
    static let details: [String] = {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let osBuild = sysctl("kern.osversion").map { " (\($0))" } ?? ""
        let memory = ProcessInfo.processInfo.physicalMemory / 1_073_741_824
        let mac = [sysctl("hw.model"), sysctl("machdep.cpu.brand_string"), "\(memory) GB"].compactMap(\.self)
        let engine = ["qBittorrent", "libtorrent-rasterbar"].compactMap { name in
            Acknowledgement.engineVersions.first { $0.hasPrefix(name + " ") }?
                .split(separator: " ").prefix(2).joined(separator: " ")
                .replacingOccurrences(of: "libtorrent-rasterbar", with: "libtorrent")
        }
        return [
            "\(AppIdentity.name) \(AboutView.version)",
            "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)\(osBuild)",
            mac.joined(separator: " · "),
            engine.isEmpty ? "Engine version unknown" : engine.joined(separator: " · "),
        ]
    }()

    /// The engine's last lines, with IP addresses and the person's user
    /// name hidden.
    static func recentLog() -> String {
        guard let log = try? String(contentsOf: EnginePaths.engineLog, encoding: .utf8) else {
            return "The engine hasn't written a log yet."
        }
        let lines = log.split(separator: "\n", omittingEmptySubsequences: true).suffix(logLines)
        return redacted(lines.joined(separator: "\n"))
    }

    static func redacted(_ text: String) -> String {
        var text = text.replacingOccurrences(of: NSHomeDirectory(), with: "~")
        let user = NSUserName()
        if user.count >= 3 { text = text.replacingOccurrences(of: user, with: "[user]") }
        text = replacing(ipv4, in: text) { _ in true }
        // IPv6 has at least three colons, or "::"; times such as 12:08:15
        // have two.
        return replacing(ipv6, in: text) { $0.count { $0 == ":" } >= 3 || $0.contains("::") }
    }

    /// Such as 161.142.139.54, also before a port.
    private static let ipv4 = try! NSRegularExpression(pattern: #"(?<![\w.])(?:\d{1,3}\.){3}\d{1,3}(?![\w.])"#)
    /// Groups of hex digits between colons, as IPv6 is written.
    private static let ipv6 = try! NSRegularExpression(pattern: #"(?<![\w.:])(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}(?![\w.:])"#)

    private static func replacing(_ pattern: NSRegularExpression, in text: String,
                                  where isAddress: (String) -> Bool) -> String {
        let result = NSMutableString(string: text)
        for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            if isAddress(result.substring(with: match.range)) {
                result.replaceCharacters(in: match.range, with: "[IP address]")
            }
        }
        return result as String
    }

    var subject: String {
        let firstLine = description.split(separator: "\n").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? ""
        let summary = firstLine.count > 60 ? firstLine.prefix(57) + "…" : firstLine
        return summary.isEmpty ? "A problem with \(AppIdentity.name)" : "\(AppIdentity.name): \(summary)"
    }

    /// The whole report, as it's sent.
    func text(log: String? = nil) -> String {
        var parts = [description.trimmingCharacters(in: .whitespacesAndNewlines),
                     "— About this Mac —\n" + Self.details.joined(separator: "\n")]
        if includesLog {
            parts.append("— Engine log, last \(Self.logLines) lines, IP addresses hidden —\n" + (log ?? Self.recentLog()))
        }
        return parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    /// A new email to `address` with the report filled in, for the mail app.
    func mailURL(log: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = Self.address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: text(log: log)),
        ]
        return components.url
    }

    private static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        let bytes = value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        let text = String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : text
    }
}
