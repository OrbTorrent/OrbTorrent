import Foundation

/// What one app on this Mac has for OrbTorrent.
struct ImportFinding: Identifiable, Sendable {
    let source: ImportSource
    let downloads: Int
    /// The app's settings that differ from OrbTorrent's.
    let settings: [ImportedSetting]
    let lastUsed: Date?

    var id: ImportSource { source }
}

/// What the welcome offers to bring over: the downloads from every app that
/// has some, and the settings from just one app, since two apps' save
/// folders or ports would clash.
struct ImportOffer: Sendable {
    /// The apps with something to bring over, most recently used first.
    let findings: [ImportFinding]
    /// The app the settings come from: the one used most recently.
    let settingsSource: ImportSource?

    init(_ found: [ImportFinding]) {
        let byUse = found.sorted { a, b in
            let (dateA, dateB) = (a.lastUsed ?? .distantPast, b.lastUsed ?? .distantPast)
            if dateA != dateB { return dateA > dateB }
            return ImportSource.allCases.firstIndex(of: a.source)! < ImportSource.allCases.firstIndex(of: b.source)!
        }
        let settingsSource = byUse.first { !$0.settings.isEmpty }?.source
        self.settingsSource = settingsSource
        findings = byUse.filter { $0.downloads > 0 || $0.source == settingsSource }
    }

    var isEmpty: Bool { findings.isEmpty }

    var sources: [ImportSource] { findings.map(\.source) }

    /// The settings that come over from this app.
    func settings(from finding: ImportFinding) -> [ImportedSetting] {
        finding.source == settingsSource ? finding.settings : []
    }

    /// What comes over from this app, such as "12 downloads and 5 settings".
    func summary(of finding: ImportFinding) -> String {
        Self.summary(downloads: finding.downloads, settings: settings(from: finding).count)
    }

    /// Whether an app's own settings are left behind for another app's.
    var leavesSettingsBehind: Bool {
        findings.contains { $0.source != settingsSource && !$0.settings.isEmpty }
    }

    /// The imports for the chosen apps.
    func jobs(for chosen: Set<ImportSource>) -> [ImportJob] {
        findings.filter { chosen.contains($0.source) }.map {
            ImportJob(source: $0.source, includesDownloads: $0.downloads > 0, settings: settings(from: $0))
        }
    }

    static func summary(downloads: Int, settings: Int) -> String {
        switch (downloads, settings) {
        case (0, 0): "Nothing new"
        case (_, 0): Format.count(downloads, "download")
        case (0, _): Format.count(settings, "setting")
        default: "\(Format.count(downloads, "download")) and \(Format.count(settings, "setting"))"
        }
    }
}
