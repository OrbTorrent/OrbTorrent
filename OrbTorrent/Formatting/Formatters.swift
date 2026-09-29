import Foundation

/// Human-readable formatting for sizes, speeds, times and ratios.
enum Format {
    static func bytes(_ value: Int64) -> String {
        max(value, 0).formatted(.byteCount(style: .file, spellsOutZero: false))
    }

    static func speed(_ bytesPerSecond: Int64) -> String {
        guard bytesPerSecond > 0 else { return "0 kB/s" }
        return "\(bytes(bytesPerSecond))/s"
    }

    /// qBittorrent reports 8640000 (100 days) when the ETA is unknown.
    static func eta(_ seconds: Int) -> String? {
        guard seconds > 0, seconds < 8_640_000 else { return nil }
        return Duration.seconds(seconds).formatted(
            .units(allowed: [.days, .hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)
        )
    }

    static func duration(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        return Duration.seconds(seconds).formatted(
            .units(allowed: [.days, .hours, .minutes], width: .abbreviated, maximumUnitCount: 2)
        )
    }

    /// How long something took: tenths of a second for a quick check, then
    /// seconds, then minutes and up.
    static func elapsed(_ seconds: TimeInterval, tenths: Bool = true) -> String {
        let seconds = max(seconds, 0)
        if seconds < 10 && tenths { return "\(max(seconds, 0.1).formatted(.number.precision(.fractionLength(1)))) s" }
        if seconds < 90 { return "\(Int(seconds)) s" }
        return Duration.seconds(seconds).formatted(
            .units(allowed: [.days, .hours, .minutes], width: .abbreviated, maximumUnitCount: 2)
        )
    }

    /// A moment as "Today at 10:04 PM", or with its date when it's older.
    static func moment(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
    }

    static func percent(_ fraction: Double) -> String {
        let clamped = min(max(fraction, 0), 1)
        // Never round an unfinished download up to 100 %.
        let digits = clamped > 0.995 && clamped < 1 ? 1 : 0
        return clamped.formatted(.percent.precision(.fractionLength(digits)))
    }

    static func ratio(_ value: Double) -> String {
        guard value >= 0 else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    static func date(_ date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    static func count(_ value: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(value) \(value == 1 ? singular : (plural ?? singular + "s"))"
    }
}
