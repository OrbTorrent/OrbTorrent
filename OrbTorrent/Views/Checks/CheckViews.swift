import AppKit
import SwiftUI

extension Color {
    /// The green of a passed check: deeper than the system green, so it holds
    /// up on the menu bar panel's glass and behind a white tick.
    static let checkPassed = Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.15, green: 0.62, blue: 0.32, alpha: 1)
            : NSColor(srgbRed: 0.11, green: 0.54, blue: 0.26, alpha: 1)
    })
}

/// What a download's checks add up to. The ring beside its name, the
/// popover, the menu bar panel and the Checks tab all show it, so they agree.
struct CheckSummary {
    /// A hook that's on but hasn't run on the download.
    struct Upcoming: Identifiable {
        let item: InstalledExtension
        let hook: ExtensionManifest.Hook
        /// It runs by itself once the download finishes; otherwise it can
        /// only be run by hand.
        let runsLater: Bool

        var id: String { "\(item.name)/\(hook.name)" }
    }

    /// Worst first.
    let records: [CheckRecord]
    let gate: ChecksStore.Gate?
    var upcoming: [Upcoming] = []

    init(records: [CheckRecord], gate: ChecksStore.Gate?, upcoming: [Upcoming] = []) {
        self.records = records.sorted { ($0.status.rank, $0.extensionTitle) < ($1.status.rank, $1.extensionTitle) }
        self.gate = gate
        self.upcoming = upcoming
    }

    /// Nothing has checked it, and nothing is about to.
    var isEmpty: Bool { records.isEmpty && gate == nil }
    var isHeld: Bool { gate == .held }
    var isChecking: Bool {
        gate == .waiting || gate == .checkOnly || records.contains { !$0.status.isFinished }
    }

    func count(_ status: CheckRecord.Status) -> Int {
        records.filter { $0.status == status }.count
    }

    /// Checks that run by themselves once the download finishes.
    var later: Int { upcoming.filter(\.runsLater).count }

    var title: String {
        if isHeld { return "Held before it started" }
        if isChecking {
            let done = records.filter(\.status.isFinished).count
            return records.isEmpty ? "Checking…" : "Checking… \(done) of \(records.count) done"
        }
        if records.isEmpty { return later > 0 ? "Checks run once it finishes" : "Not checked yet" }
        let failed = count(.failed), warned = count(.warning), passed = count(.passed)
        let skipped = count(.skipped), unfinished = count(.didNotFinish)
        var parts: [String] = []
        if failed > 0 { parts.append(failed == 1 ? "1 found a problem" : "\(failed) found problems") }
        if warned > 0 { parts.append(warned == 1 ? "1 warning" : "\(warned) warnings") }
        if passed > 0 {
            parts.append(parts.isEmpty && skipped + unfinished + later == 0
                         ? (passed == 1 ? "Passed" : "All \(passed) passed")
                         : "\(passed) passed")
        }
        if skipped > 0 { parts.append("\(skipped) skipped") }
        if unfinished > 0 { parts.append("\(unfinished) didn't finish") }
        if later > 0 { parts.append("\(later) more once it finishes") }
        return parts.joined(separator: " · ")
    }

    /// Which extensions checked it.
    var byline: String {
        var titles: [String] = []
        for title in records.map(\.extensionTitle) where !titles.contains(title) { titles.append(title) }
        switch titles.count {
        case 0: return isChecking ? "Extensions are looking at it" : ""
        case 1, 2: return "\(isChecking ? "Checking with" : "Checked by") \(ListFormatter.localizedString(byJoining: titles))"
        default: return "\(isChecking ? "Checking with" : "Checked by") \(titles.count) extensions"
        }
    }

    /// The colour of the worst result.
    var tint: Color {
        if isHeld { return .orange }
        if count(.failed) > 0 { return .red }
        if count(.warning) > 0 { return .yellow }
        if count(.didNotFinish) > 0 { return .orange }
        if isChecking { return .accentColor }
        if count(.passed) > 0 { return .checkPassed }
        return .secondary
    }

    /// The mark in the badge's middle. A problem shows at once, but a check
    /// only once every check has finished and found nothing: while checks
    /// run there's none, and while some are still to come, a clock.
    var mark: CheckMark.Kind? {
        if count(.failed) > 0 { return .cross }
        if count(.warning) > 0 || count(.didNotFinish) > 0 { return .exclamation }
        if isChecking { return nil }
        if later > 0 { return .clock }
        if count(.passed) > 0 { return .check }
        return count(.skipped) > 0 ? .minus : nil
    }

    /// One colour per check, worst first, then those still to come.
    var segments: [Color] {
        records.map(\.status.ringColor) + Array(repeating: CheckRecord.Status.pendingColor, count: later)
    }
}

extension CheckRecord.Status {
    /// Worst first.
    var rank: Int {
        switch self {
        case .failed: 0
        case .warning: 1
        case .didNotFinish: 2
        case .running: 3
        case .queued: 4
        case .skipped: 5
        case .passed: 6
        }
    }

    var tint: Color {
        switch self {
        case .failed: .red
        case .warning: .yellow
        case .didNotFinish: .orange
        case .passed: .checkPassed
        case .running, .queued, .skipped: .secondary
        }
    }

    static let pendingColor = Color.secondary.opacity(0.3)

    var ringColor: Color {
        switch self {
        case .running, .queued: Self.pendingColor
        case .skipped: .secondary.opacity(0.6)
        default: tint
        }
    }

    /// The mark for this result; a running check spins instead.
    var mark: CheckMark.Kind? {
        switch self {
        case .failed: .cross
        case .warning, .didNotFinish: .exclamation
        case .passed: .check
        case .skipped: .minus
        case .queued: .clock
        case .running: nil
        }
    }
}

extension CheckRecord {
    /// What it found, or what it's doing.
    var displaySummary: String {
        switch status {
        case .queued: "Waiting for another check to finish…"
        case .running: progress?.message ?? "Checking…"
        default: summary
        }
    }
}

extension Extensions {
    /// A download's checks, and the hooks that are on but haven't run on it.
    /// Every view asks for both, so a ring reads the same everywhere. Reports
    /// on the checks aren't checks themselves, so they're left out.
    func summary(of torrent: Torrent) -> CheckSummary {
        // Off, checks don't show anywhere.
        guard isOn else { return CheckSummary(records: [], gate: nil) }
        let records = checks.records(for: torrent.hash).filter { $0.event != .afterChecks }
        let gate = checks.gate(for: torrent.hash)
        var upcoming: [CheckSummary.Upcoming] = []
        let ran = Set(records.map(\.id))
        for item in registry.extensions where registry.isEnabled(item) && item.isCompatible {
            for hook in item.manifest.hooks where !ran.contains("\(item.name)/\(hook.name)") {
                switch hook.event {
                case .beforeStart where gate == nil:
                    upcoming.append(.init(item: item, hook: hook, runsLater: false))
                case .afterFinish:
                    upcoming.append(.init(item: item, hook: hook, runsLater: !torrent.isComplete))
                default:
                    break
                }
            }
        }
        return CheckSummary(records: records, gate: gate, upcoming: upcoming)
    }

    /// The reports on a download's checks, and those that are on but haven't
    /// run on it, for its Checks tab.
    func reports(of torrent: Torrent) -> (records: [CheckRecord], upcoming: [CheckSummary.Upcoming]) {
        guard isOn else { return ([], []) }
        let records = checks.records(for: torrent.hash).filter { $0.event == .afterChecks }
        let ran = Set(records.map(\.id))
        var upcoming: [CheckSummary.Upcoming] = []
        for item in registry.extensions where registry.isEnabled(item) && item.isCompatible {
            for hook in item.manifest.hooks(for: .afterChecks) where !ran.contains("\(item.name)/\(hook.name)") {
                upcoming.append(.init(item: item, hook: hook, runsLater: !canRun(hook, on: torrent)))
            }
        }
        return (records.sorted { $0.extensionTitle < $1.extensionTitle }, upcoming)
    }

    /// The problems checks found with each of a download's files, by index,
    /// worst first.
    func fileProblems(of hash: String) -> [Int: [FileFinding]] {
        guard isOn else { return [:] }
        var problems: [Int: [FileFinding]] = [:]
        for record in checks.records(for: hash) {
            for file in record.files ?? [] where file.status == .failed || file.status == .warning {
                problems[file.index, default: []].append(FileFinding(extensionTitle: record.extensionTitle, result: file))
            }
        }
        return problems.mapValues { $0.sorted { $0.result.status.rank < $1.result.status.rank } }
    }
}

/// What one check found about a file, with the extension that found it.
struct FileFinding: Equatable {
    let extensionTitle: String
    let result: CheckRecord.FileResult

    /// Such as "VirusTotal Scan: 5 of 70 engines call it malicious".
    var line: String {
        "\(extensionTitle): \(result.summary ?? result.status.title)"
    }

    /// The reason first, for a row too narrow for all of it, such as
    /// "5 of 70 engines call it malicious · VirusTotal Scan".
    var reason: String {
        "\(result.summary ?? result.status.title) · \(extensionTitle)"
    }
}

// MARK: - The ring

/// A check result's mark as lines, so it can share its ring's stroke instead
/// of a symbol's own weight.
struct CheckMark: Shape {
    enum Kind {
        case check, cross, exclamation, minus, clock
    }

    let kind: Kind

    /// The line every ring and mark of this size uses. It grows more slowly
    /// past about 16 pt, so a large ring stays as light as a small one looks.
    static func lineWidth(for size: CGFloat) -> CGFloat {
        max(1.5, min(size * 0.13, 1.2 + size * 0.055))
    }

    static func style(_ lineWidth: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        var path = Path()
        switch kind {
        case .check:
            path.move(to: point(0.3, 0.52))
            path.addLine(to: point(0.44, 0.66))
            path.addLine(to: point(0.7, 0.37))
        case .cross:
            path.move(to: point(0.35, 0.35))
            path.addLine(to: point(0.65, 0.65))
            path.move(to: point(0.65, 0.35))
            path.addLine(to: point(0.35, 0.65))
        case .exclamation:
            path.move(to: point(0.5, 0.3))
            path.addLine(to: point(0.5, 0.55))
            // A dot: a line too short to see, drawn with round ends.
            path.move(to: point(0.5, 0.7))
            path.addLine(to: point(0.5, 0.701))
        case .minus:
            path.move(to: point(0.33, 0.5))
            path.addLine(to: point(0.67, 0.5))
        case .clock:
            path.move(to: point(0.5, 0.3))
            path.addLine(to: point(0.5, 0.5))
            path.addLine(to: point(0.64, 0.6))
        }
        return path
    }
}

/// A ring with one segment per check, coloured by its result.
struct CheckSegments: View {
    let colors: [Color]
    let lineWidth: CGFloat

    var body: some View {
        let count = colors.count
        // A little space between segments, less as there are more of them.
        let gap = count > 1 ? min(0.03, 0.3 / Double(count)) : 0
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                Circle()
                    .trim(from: Double(index) / Double(count) + gap / 2, to: Double(index + 1) / Double(count) - gap / 2)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
        }
        .rotationEffect(.degrees(-90))
        .padding(lineWidth / 2)
    }
}

/// A download's checks on the corner of its icon: one solid dot in the worst
/// result's colour, with its mark, whose edge is a ring with a segment for
/// each check. When every check agrees it's a plain dot; the edge shows
/// where they differ, a check still to come in grey, or checks running.
/// It needs no border: a solid dot stands clear of the icon on any row.
struct CheckRingBadge: View {
    let summary: CheckSummary
    var size: CGFloat = 18

    /// Checks still to come: solid grey, so it shows against any colour.
    private static let pending = Color(white: 0.55)

    var body: some View {
        let ring = max(2, size * 0.14)
        ZStack {
            Circle()
                .fill(fill)
            CheckSegments(colors: summary.isHeld ? [.orange] : summary.segments.map { $0 == CheckRecord.Status.pendingColor ? Self.pending : $0 },
                          lineWidth: ring)
            if summary.isChecking && !summary.isHeld {
                CheckSpinner(lineWidth: ring)
            }
            if summary.isHeld {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: size * 0.45, weight: .bold))
                    .foregroundStyle(.white)
            } else if let mark {
                CheckMark(kind: mark)
                    .stroke(markStyle, style: CheckMark.style(max(1.4, size * 0.1)))
                    .padding(ring * 0.6)
            }
        }
        .frame(width: size, height: size)
    }

    /// Green only once every check has passed. Until then the dot is grey,
    /// and its edge fills in green as checks pass.
    private var mark: CheckMark.Kind? { summary.mark }

    private var fill: Color {
        if summary.isHeld { return .orange }
        switch mark {
        case .cross: return .red
        case .exclamation: return summary.count(.warning) > 0 ? .yellow : .orange
        case .check: return .checkPassed
        case .minus, .clock, nil: return .gray
        }
    }

    private var markStyle: Color {
        mark == .exclamation && summary.count(.warning) > 0 ? .black.opacity(0.7) : .white
    }
}

extension View {
    /// Puts a download's check ring on the bottom-right corner of its icon.
    func checkBadge<Badge: View>(@ViewBuilder _ badge: () -> Badge) -> some View {
        overlay(alignment: .bottomTrailing) {
            badge()
                .offset(x: 6, y: 6)
        }
    }
}

/// A turning arc, for checks that are running. It holds still while its
/// window can't be seen.
struct CheckSpinner: View {
    var lineWidth: CGFloat = 2
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !isVisible)) { context in
            let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(turn * 360 - 90))
                .padding(lineWidth / 2)
        }
        .background(WindowVisibilityObserver { isVisible = $0 })
    }
}

/// A check's result as a small filled dot, for the corner of an extension's icon.
struct CheckStatusDot: View {
    let status: CheckRecord.Status
    var size: CGFloat = 12

    var body: some View {
        let line = CheckMark.lineWidth(for: size)
        ZStack {
            Circle()
                .fill(isFilled ? AnyShapeStyle(status.tint) : AnyShapeStyle(.background))
            if !isFilled && status != .running {
                // Waiting or skipped: an outline, so the dot doesn't vanish.
                Circle()
                    .strokeBorder(.secondary.opacity(0.7), lineWidth: line * 0.75)
                    .padding(max(1, size * 0.1))
            }
            if status == .running {
                CheckSpinner(lineWidth: line)
                    .padding(size * 0.12)
            } else if let mark = status.mark {
                CheckMark(kind: mark)
                    .stroke(markStyle, style: CheckMark.style(line))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.background, lineWidth: max(1, size * 0.1)))
        .help(status.title)
    }

    private var isFilled: Bool {
        status.isFinished && status != .skipped
    }

    private var markStyle: AnyShapeStyle {
        switch status {
        case .warning: AnyShapeStyle(.black.opacity(0.7))
        case .queued, .skipped: AnyShapeStyle(.secondary)
        default: AnyShapeStyle(.white)
        }
    }
}

/// An extension's icon with its check's result on the corner, so a list of
/// many checks can be read by icon.
struct ExtensionCheckIcon: View {
    @Environment(AppModel.self) private var model
    let extensionName: String
    let status: CheckRecord.Status?
    var size: CGFloat = 24

    var body: some View {
        ExtensionIcon(url: model.extensions.registry.named(extensionName)?.iconURL, size: size)
            .overlay(alignment: .bottomTrailing) {
                if let status {
                    CheckStatusDot(status: status, size: max(11, size * 0.5))
                        .offset(x: size * 0.14, y: size * 0.14)
                }
            }
    }
}

// MARK: - Summary and lists

/// The ring with what it means, above a list of checks.
struct CheckSummaryHeader: View {
    let summary: CheckSummary
    var ringSize: CGFloat = 28

    var body: some View {
        HStack(spacing: 10) {
            CheckRingBadge(summary: summary, size: ringSize)
            VStack(alignment: .leading, spacing: 1) {
                Text(summary.title)
                    .font(ringSize >= 28 ? .headline : .callout.weight(.semibold))
                if !summary.byline.isEmpty {
                    Text(summary.byline)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Where a check's icon ends and its text begins, so a list of checks can
/// line up with the rows around it.
struct CheckColumns {
    /// The icon's size. It sits at the end of its slot.
    var icon: CGFloat = 26
    var slot: CGFloat = 26
    var gap: CGFloat = 10
}

/// One check in a short list: the popover, the menu bar and the add sheet.
struct CheckLine: View {
    let record: CheckRecord
    var columns = CheckColumns()

    var body: some View {
        HStack(alignment: .top, spacing: columns.gap) {
            ExtensionCheckIcon(extensionName: record.extensionName, status: record.status, size: columns.icon)
                .frame(width: columns.slot, alignment: .trailing)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(record.extensionTitle)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if let link = record.link {
                        ReportLink(link: link)
                    }
                }
                Text(record.displaySummary)
                    .font(.caption)
                    .foregroundStyle(record.status == .failed ? .primary : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !record.status.isFinished, let done = record.progress?.done, let total = record.progress?.total, total > 0 {
                    ProgressView(value: Double(done), total: Double(total))
                        .controlSize(.mini)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A download's checks, problems first. Past four, the ones that passed fold
/// into one line, the way a pull request hides its passing checks.
struct CompactCheckList: View {
    let summary: CheckSummary
    var showsUpcoming = true
    var columns = CheckColumns()
    @State private var showsPassed = false

    var body: some View {
        let folds = summary.records.count > 4 && summary.count(.passed) > 1
        let shown = folds && !showsPassed ? summary.records.filter { $0.status != .passed } : summary.records
        VStack(alignment: .leading, spacing: 10) {
            ForEach(shown) { CheckLine(record: $0, columns: columns).fadesIn() }
            if folds {
                Button {
                    showsPassed.toggle()
                } label: {
                    HStack(spacing: columns.gap) {
                        // Under the middle of the icons above.
                        CheckStatusIcon(status: .passed, size: 13)
                            .frame(width: columns.icon)
                            .frame(width: columns.slot, alignment: .trailing)
                        Text(showsPassed ? "Hide passed checks" : "\(summary.count(.passed)) passed")
                        Image(systemName: showsPassed ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .font(.callout)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            if showsUpcoming {
                ForEach(summary.upcoming.filter(\.runsLater)) { upcoming in
                    HStack(spacing: columns.gap) {
                        ExtensionCheckIcon(extensionName: upcoming.item.name, status: .queued, size: columns.icon)
                            .opacity(0.6)
                            .frame(width: columns.slot, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(upcoming.item.title)
                                .font(.callout.weight(.medium))
                            Text("Runs once the download finishes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// Nothing downloads until the user decides.
struct HeldActions: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing downloads until you decide. If you didn't expect what a check found, remove it.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("Download Anyway") { Task { await model.extensions.downloadAnyway(torrent.hash) } }
                Button("Remove…", role: .destructive) { model.requestRemoval(of: [torrent]) }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.orange.opacity(0.3)))
    }
}

/// The badge on a download's icon. Clicking it lists the checks.
struct CheckRingButton: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    var size: CGFloat = 18
    @State private var isShowingChecks = false

    var body: some View {
        let summary = model.extensions.summary(of: torrent)
        if !summary.isEmpty {
            Button {
                isShowingChecks.toggle()
            } label: {
                CheckRingBadge(summary: summary, size: size)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .help(summary.title)
            .accessibilityLabel("Checks: \(summary.title)")
            .popover(isPresented: $isShowingChecks, arrowEdge: .bottom) {
                ChecksPopover(torrent: torrent)
            }
        }
    }
}

/// A download's checks at a glance, from the ring beside its name.
struct ChecksPopover: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent

    var body: some View {
        let summary = model.extensions.summary(of: torrent)
        VStack(alignment: .leading, spacing: 12) {
            CheckSummaryHeader(summary: summary, ringSize: 30)
            if summary.isHeld {
                HeldActions(torrent: torrent)
            }
            Divider()
            CompactCheckList(summary: summary)
            Divider()
            HStack {
                Spacer()
                QuietLink(title: "Show in the Checks Tab") { model.showChecks(of: torrent.hash) }
            }
        }
        .padding(14)
        .frame(width: 340)
    }
}

/// A check's report link as a grey arrow that brightens under the pointer,
/// so it sits quietly on glass.
struct ReportLink: View {
    let link: CheckRecord.Link
    @Environment(\.openURL) private var openURL
    @State private var isHovered = false

    var body: some View {
        Button {
            openURL(link.url)
        } label: {
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(isHovered ? .primary : .secondary)
                .frame(width: 18, height: 18)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(link.title)
        .accessibilityLabel(link.title)
    }
}

/// A way out that doesn't compete with the content: grey text and a
/// chevron.
struct QuietLink: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Text(title)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(isHovered ? .primary : .secondary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

/// Checks as one line, with the ring and the extensions that checked it,
/// which opens into the list. The menu bar panel and the add sheets show it.
struct ChecksCard: View {
    @Environment(AppModel.self) private var model
    let summary: CheckSummary
    @Binding var isOpen: Bool
    /// The download, once it's in the library: for Download Anyway and a
    /// way to its Checks tab.
    var torrent: Torrent?
    /// The ring's size, and the extensions' icons' in the open card: one
    /// column, so the title and every check's name start together.
    var iconSize: CGFloat = 22

    private static let padding: CGFloat = PanelGrid.cardPadding
    private let gap: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Opens at once: the menu bar panel's window fits its content, so
            // animating the height would make the window judder.
            Button {
                guard canToggle else { return }
                isOpen.toggle()
            } label: {
                HStack(spacing: gap) {
                    CheckRingBadge(summary: summary, size: iconSize)
                    Text(summary.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if !isOpen {
                        icons
                    }
                    if canToggle {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                            .animation(.snappy, value: isOpen)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .help(isOpen ? "Hide checks" : "Show checks")
            .accessibilityLabel("Checks: \(summary.title)")

            if isOpen && (summary.isHeld || !summary.records.isEmpty) {
                // Edge to edge, between the summary and the checks.
                Divider()
                    .padding(.horizontal, -Self.padding)
                VStack(alignment: .leading, spacing: 12) {
                    if summary.isHeld, let torrent {
                        HeldActions(torrent: torrent)
                    }
                    CompactCheckList(summary: summary, columns: CheckColumns(icon: iconSize, slot: iconSize, gap: gap))
                    if let torrent {
                        HStack {
                            Spacer()
                            QuietLink(title: "Show in OrbTorrent") { model.showChecks(of: torrent.hash) }
                        }
                    }
                }
                .fadesIn()
            }
        }
        .padding(Self.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(edge))
    }

    /// A held download's card stays open, and there's nothing to open until
    /// a check has started.
    private var canToggle: Bool {
        !summary.isHeld && !summary.records.isEmpty
    }

    /// The worst result tints the edge, so it shows even while closed.
    private var edge: AnyShapeStyle {
        if summary.isHeld || summary.count(.failed) + summary.count(.warning) + summary.count(.didNotFinish) > 0 {
            return AnyShapeStyle(summary.tint.opacity(0.4))
        }
        return AnyShapeStyle(.quaternary.opacity(0.6))
    }

    /// The extensions that checked it, overlapping.
    private var icons: some View {
        var names: [String] = []
        for name in summary.records.map(\.extensionName) where !names.contains(name) { names.append(name) }
        let registry = model.extensions.registry
        return HStack(spacing: -5) {
            ForEach(names.prefix(4), id: \.self) { name in
                ExtensionIcon(url: registry.named(name)?.iconURL, size: 18)
                    .overlay(RoundedRectangle(cornerRadius: 4.5).strokeBorder(.background, lineWidth: 1))
            }
            if names.count > 4 {
                Text("+\(names.count - 4)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }
}

extension View {
    /// Fades in once it appears. Only its opacity changes, so a window that
    /// fits its content, like the menu bar panel, resizes once instead of
    /// following an animation.
    func fadesIn() -> some View {
        modifier(FadeIn())
    }
}

private struct FadeIn: ViewModifier {
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible || reduceMotion ? 1 : 0)
            .onAppear {
                withAnimation(.easeOut(duration: 0.22)) { isVisible = true }
            }
    }
}
