import SwiftUI

/// Extensions' checks on a download, like the checks on a pull request: a
/// summary, then the download's life from being added to done, as on the
/// Extensions page, with the checks where they ran and how long each step took.
struct ChecksTabView: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent

    private var extensions: Extensions { model.extensions }

    var body: some View {
        let summary = extensions.summary(of: torrent)
        let reports = extensions.reports(of: torrent)
        if summary.isEmpty && summary.upcoming.isEmpty && reports.records.isEmpty && reports.upcoming.isEmpty {
            empty
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CheckSummaryHeader(summary: summary, ringSize: 34)
                    CheckTimeline(summary: summary, torrent: torrent)
                    ReportsSection(records: reports.records, upcoming: reports.upcoming, torrent: torrent)
                }
                .padding(16)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    private var empty: some View {
        let anyOn = extensions.registry.extensions.contains(where: extensions.registry.isEnabled)
        return VStack(spacing: 10) {
            Image(systemName: "checkmark.shield")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(anyOn ? "No checks have run on this download." : "Turn on an extension to check downloads.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if !anyOn {
                Button("Show Extensions") { model.showExtensions() }
                    .buttonStyle(.link)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Reports on the checks, such as a message to the user's phone. They aren't
/// checks themselves, so they sit below the download's life, not in it.
private struct ReportsSection: View {
    let records: [CheckRecord]
    let upcoming: [CheckSummary.Upcoming]
    let torrent: Torrent

    var body: some View {
        if !records.isEmpty || !upcoming.isEmpty {
            let event = ExtensionManifest.Event.afterChecks
            VStack(alignment: .leading, spacing: 8) {
                Label(event.stageTitle, systemImage: event.symbol)
                    .font(.subheadline.weight(.semibold))
                ForEach(records) { CheckCard(record: $0, torrent: torrent) }
                ForEach(upcoming) { UpcomingCard(upcoming: $0, torrent: torrent) }
            }
        }
    }
}

// MARK: - Timeline

/// The same steps as the Extensions page's strip, top to bottom: added, the
/// checks before it starts, downloading, the checks after it finishes, done.
private struct CheckTimeline: View {
    @Environment(AppModel.self) private var model
    let summary: CheckSummary
    let torrent: Torrent

    private var before: [CheckRecord] { summary.records.filter { $0.event == .beforeStart } }
    private var after: [CheckRecord] { summary.records.filter { $0.event == .afterFinish } }

    var body: some View {
        let beforeState = beforeState
        let downloadState = downloadState
        let afterState = afterState
        let doneState = doneState
        VStack(alignment: .leading, spacing: 0) {
            TimelineStep("Added", symbol: "plus", state: .reached, next: beforeState,
                         subtitle: torrent.addedOn.map(Format.moment))
            TimelineStep(ExtensionManifest.Event.beforeStart.stageTitle,
                         symbol: summary.isHeld ? "hand.raised.fill" : "hand.raised",
                         state: beforeState, next: downloadState,
                         subtitle: beforeSubtitle, timing: timing(of: before)) {
                StageChecks(event: .beforeStart, summary: summary, torrent: torrent)
            }
            TimelineStep("Downloading", symbol: "arrow.down", state: downloadState, next: afterState,
                         subtitle: downloadSubtitle(downloadState), live: downloadState == .current,
                         timing: downloadTiming(downloadState)) {
                if downloadState == .current {
                    ProgressCapsule(value: torrent.progress, tint: torrent.tint, height: 4)
                        .padding(.top, 2)
                }
            }
            TimelineStep(ExtensionManifest.Event.afterFinish.stageTitle, symbol: "flag.checkered",
                         state: afterState, next: doneState,
                         subtitle: after.isEmpty && !summary.upcoming.contains { $0.hook.event == .afterFinish } ? "No checks" : nil,
                         timing: timing(of: after)) {
                StageChecks(event: .afterFinish, summary: summary, torrent: torrent)
            }
            TimelineStep("Done", symbol: "checkmark", state: doneState, next: nil,
                         subtitle: doneSubtitle(doneState))
        }
    }

    // MARK: Where the download is

    private var beforeState: StepState {
        if summary.isHeld { return .attention }
        let waits = summary.gate == .waiting || summary.gate == .checkOnly
        return waits || before.contains { !$0.status.isFinished } ? .current : .reached
    }

    private var downloadState: StepState {
        if torrent.isComplete { return .reached }
        return summary.gate == nil ? .current : .ahead
    }

    private var afterState: StepState {
        guard torrent.isComplete else { return .ahead }
        return after.contains { !$0.status.isFinished } ? .current : .reached
    }

    private var doneState: StepState {
        afterState == .reached ? .reached : .ahead
    }

    // MARK: What each step says

    private var beforeSubtitle: String? {
        if summary.isHeld { return "Held until you decide" }
        if before.isEmpty {
            if summary.gate != nil { return torrent.hasMetadata ? "Checking…" : "Waiting for the file list from peers" }
            if !summary.upcoming.contains(where: { $0.hook.event == .beforeStart }) { return "No checks" }
        }
        return nil
    }

    private func downloadSubtitle(_ state: StepState) -> String? {
        switch state {
        case .reached:
            let size = Format.bytes(torrent.size)
            guard let took = downloadTook, took >= 1 else { return size }
            return "\(size) · \(Format.speed(Int64(Double(torrent.size) / took))) on average"
        case .current, .attention:
            if torrent.state.activity == .downloading, torrent.size > 0 {
                // The step's title already says it's downloading.
                let of = "\(Format.bytes(torrent.downloadedSize)) of \(Format.bytes(torrent.size))"
                return [of, Format.eta(torrent.eta).map { "\($0) left" }].compactMap { $0 }.joined(separator: " · ")
            }
            return torrent.statusLine(waitingForSpace: model.store.waitingForSpace.contains(torrent.hash))
        case .ahead:
            if summary.isHeld { return "Starts once you decide" }
            if summary.gate == .checkOnly { return "Stays paused after its checks" }
            return "Starts once its checks pass"
        }
    }

    private func downloadTiming(_ state: StepState) -> StepTiming? {
        switch state {
        case .reached: downloadTook.map { .took($0) }
        case .current: downloadStarted.map { .running(since: $0) }
        default: nil
        }
    }

    private func doneSubtitle(_ state: StepState) -> String? {
        guard state == .reached, let done = doneAt else { return nil }
        guard let added = torrent.addedOn, done > added else { return Format.moment(done) }
        return "\(Format.moment(done)) · \(Format.elapsed(done.timeIntervalSince(added), tenths: false)) in all"
    }

    // MARK: Times

    /// When it began downloading: once its checks before it starts were
    /// done, or when it was added.
    private var downloadStarted: Date? {
        let completed = torrent.completedOn ?? .distantFuture
        // A check run again later doesn't move the start.
        let checked = before.compactMap(\.finishedAt).filter { $0 < completed }.max()
        return [torrent.addedOn, checked].compactMap { $0 }.max()
    }

    private var downloadTook: TimeInterval? {
        guard let start = downloadStarted, let end = torrent.completedOn, end > start else { return nil }
        return end.timeIntervalSince(start)
    }

    /// When the checks after it finished were done, or when it finished.
    private var doneAt: Date? {
        guard let completed = torrent.completedOn else { return nil }
        return ([completed] + after.compactMap(\.finishedAt).filter { $0 >= completed }).max()
    }

    /// How long a stage's checks took, or how long they've been going.
    private func timing(of records: [CheckRecord]) -> StepTiming? {
        guard !records.isEmpty, let start = records.compactMap(\.startedAt).min() else { return nil }
        guard records.allSatisfy(\.status.isFinished) else { return .running(since: start) }
        guard let end = records.compactMap(\.finishedAt).max() else { return nil }
        return .took(end.timeIntervalSince(start))
    }
}

/// How far a download has come to a step.
private enum StepState {
    case reached
    /// Where the download is now.
    case current
    /// Where it waits on the user.
    case attention
    case ahead
}

private enum StepTiming {
    case took(TimeInterval)
    case running(since: Date)
}

private enum TimelineMetrics {
    static let circle: CGFloat = 28
    static let gap: CGFloat = 10
    /// Between one step's end and the next step's circle.
    static let spacing: CGFloat = 18
}

/// One step: its circle on the line, its title and time, and what happened there.
private struct TimelineStep<Content: View>: View {
    let title: String
    let symbol: String
    let state: StepState
    /// The step the line leads on to. The last step has none.
    let next: StepState?
    let subtitle: String?
    /// A subtitle that changes every second keeps to one line, so what's
    /// below it doesn't jump up and down as it gets longer and shorter.
    let live: Bool
    let timing: StepTiming?
    let content: Content

    init(_ title: String, symbol: String, state: StepState, next: StepState?, subtitle: String? = nil,
         live: Bool = false, timing: StepTiming? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.state = state
        self.next = next
        self.subtitle = subtitle
        self.live = live
        self.timing = timing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: TimelineMetrics.gap) {
                // The circle's middle sits on the title's, and its top on the step's.
                StepCircle(symbol: symbol, state: state)
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                VStack(alignment: .leading, spacing: 2) {
                    // The time sits beside the title, leaving the subtitle the whole width.
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(state == .ahead ? .secondary : .primary)
                        Spacer(minLength: 8)
                        if let timing {
                            TimingText(timing: timing)
                        }
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(state == .attention ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                            .monospacedDigit()
                            .lineLimit(live ? 1 : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            content
                .padding(.leading, TimelineMetrics.circle + TimelineMetrics.gap)
        }
        .padding(.bottom, next == nil ? 0 : TimelineMetrics.spacing)
        .background(alignment: .topLeading) {
            if let next {
                // Dotted on to a step it hasn't reached.
                VerticalLine()
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: next == .ahead ? [0.1, 5] : []))
                    .frame(width: TimelineMetrics.circle)
                    .padding(.top, TimelineMetrics.circle + 5)
                    .padding(.bottom, 5)
            }
        }
    }
}

extension TimelineStep where Content == EmptyView {
    init(_ title: String, symbol: String, state: StepState, next: StepState?, subtitle: String? = nil,
         live: Bool = false, timing: StepTiming? = nil) {
        self.init(title, symbol: symbol, state: state, next: next, subtitle: subtitle, live: live, timing: timing) { EmptyView() }
    }
}

/// A step's circle, like the milestones on the Extensions page. The step the
/// download is at stands out; those ahead are outlines.
private struct StepCircle: View {
    let symbol: String
    let state: StepState

    var body: some View {
        let size = TimelineMetrics.circle
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(foreground)
            .frame(width: size, height: size)
            .background(background, in: .circle)
            .overlay {
                Circle().strokeBorder(border, style: StrokeStyle(lineWidth: 1, dash: state == .ahead ? [3, 2.5] : []))
            }
    }

    private var tint: Color? {
        switch state {
        case .current: .accentColor
        case .attention: .orange
        case .reached, .ahead: nil
        }
    }

    private var foreground: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint) }
        return state == .ahead ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)
    }

    private var background: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint.opacity(0.16)) }
        return state == .ahead ? AnyShapeStyle(.clear) : AnyShapeStyle(.quaternary)
    }

    private var border: AnyShapeStyle {
        if let tint { return AnyShapeStyle(tint.opacity(0.5)) }
        return state == .ahead ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.clear)
    }
}

private struct VerticalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}

/// How long a step or check took, or, while it's going, how long so far.
private struct TimingText: View {
    let timing: StepTiming

    var body: some View {
        Group {
            switch timing {
            case .took(let seconds):
                Text(Format.elapsed(seconds))
                    .help("How long it took")
            case .running(let start):
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(Format.elapsed(context.date.timeIntervalSince(start), tenths: false))
                }
                .help("How long it's been going")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
    }
}

/// The checks at one stage: what ran, and what's still to run. Many passing
/// checks fold into one line, so problems stay in view.
private struct StageChecks: View {
    @Environment(AppModel.self) private var model
    let event: ExtensionManifest.Event
    let summary: CheckSummary
    let torrent: Torrent
    @State private var showsPassed = false

    var body: some View {
        let records = summary.records.filter { $0.event == event }
        let upcoming = summary.upcoming.filter { $0.hook.event == event }
        let passed = records.filter { $0.status == .passed }
        let folds = passed.count > 3
        let shown = folds && !showsPassed ? records.filter { $0.status != .passed } : records
        let isHeld = event == .beforeStart && summary.isHeld
        if !records.isEmpty || !upcoming.isEmpty || isHeld {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(shown) { CheckCard(record: $0, torrent: torrent) }
                if folds {
                    Button {
                        withAnimation(.snappy) { showsPassed.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            CheckStatusIcon(status: .passed, size: 13)
                            Text(showsPassed ? "Hide passed checks" : "\(passed.count) more passed")
                            Image(systemName: showsPassed ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .font(.callout)
                        .padding(.vertical, 4)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
                if isHeld {
                    heldActions
                }
                ForEach(upcoming) { UpcomingCard(upcoming: $0, torrent: torrent) }
            }
        }
    }

    /// What the user decides for a held download, below the check that held it.
    private var heldActions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing downloads until you decide. If you didn't expect what the check found, remove it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Download Anyway") { Task { await model.extensions.downloadAnyway(torrent.hash) } }
                Button("Remove…", role: .destructive) { model.requestRemoval(of: [torrent]) }
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.3)))
    }
}

/// One extension's result, in full.
private struct CheckCard: View {
    @Environment(AppModel.self) private var model
    let record: CheckRecord
    let torrent: Torrent
    @State private var showsDetails = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ExtensionCheckIcon(extensionName: record.extensionName, status: record.status, size: 30)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(record.extensionTitle)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    StatusChip(status: record.status)
                    Spacer(minLength: 6)
                    if let timing {
                        TimingText(timing: timing)
                    }
                }
                Text(record.displaySummary)
                    .font(.callout)
                    .foregroundStyle(record.status == .failed ? .primary : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if record.status.isFinished, let files = record.files, !files.isEmpty {
                    FileResultsList(files: files, torrent: torrent)
                }
                if let added = record.addedFiles, !added.isEmpty {
                    AddedFilesList(paths: added)
                }
                if !record.status.isFinished, let done = record.progress?.done, let total = record.progress?.total, total > 0 {
                    VStack(alignment: .leading, spacing: 3) {
                        ProgressView(value: Double(done), total: Double(total))
                            .controlSize(.small)
                        Text("\(done) of \(total)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                actions
                if showsDetails, let details = record.details {
                    MarkdownText(details)
                        .font(.callout)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.opacity(0.5), in: .rect(cornerRadius: 8))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quinary, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(borderStyle))
    }

    /// How long it took, or how long it's been checking.
    private var timing: StepTiming? {
        guard let start = record.startedAt else { return nil }
        if record.status == .running { return .running(since: start) }
        guard record.status.isFinished, let end = record.finishedAt else { return nil }
        return .took(end.timeIntervalSince(start))
    }

    /// A problem gets a tinted edge, so it stands out in a long list.
    private var borderStyle: AnyShapeStyle {
        switch record.status {
        case .failed: AnyShapeStyle(.red.opacity(0.45))
        case .warning: AnyShapeStyle(.yellow.opacity(0.45))
        default: AnyShapeStyle(.quaternary.opacity(0.6))
        }
    }

    @ViewBuilder
    private var actions: some View {
        let item = model.extensions.registry.named(record.extensionName)
        let hook = item?.manifest.hooks.first { $0.name == record.hookName }
        let canRunAgain = item != nil && record.status.isFinished
            && hook.map { model.extensions.canRun($0, on: torrent) } == true
        let needsSetup = item.map { !model.extensions.settings.missing(for: $0).isEmpty } ?? false
        let added = record.addedFiles ?? []
        if record.details != nil || record.link != nil || !added.isEmpty || canRunAgain || needsSetup {
            HStack(spacing: 14) {
                if record.details != nil {
                    Button(showsDetails ? "Hide Details" : "Details") {
                        withAnimation(.snappy) { showsDetails.toggle() }
                    }
                }
                if !added.isEmpty {
                    Button("Show in Finder") { FileActions.revealAdded(added, of: torrent) }
                }
                if let link = record.link {
                    Link(destination: link.url) {
                        Label(link.title, systemImage: "arrow.up.right")
                    }
                }
                if needsSetup, let item {
                    Button("Set Up") { model.showExtensions(item.name) }
                }
                if canRunAgain, let item, let hook {
                    Button("Run Again") { Task { await model.extensions.runAgain(item, hook, on: torrent) } }
                }
            }
            .buttonStyle(.link)
            .font(.callout)
            .padding(.top, 1)
        }
    }
}

/// What a check found about particular files: problems as rows, each with
/// the way to it, and the files that passed as a count.
private struct FileResultsList: View {
    let files: [CheckRecord.FileResult]
    let torrent: Torrent
    @State private var showsAll = false
    private static let shown = 5

    var body: some View {
        let problems = files.filter { $0.status != .passed }
        let passed = files.count - problems.count
        if !problems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(showsAll ? problems : Array(problems.prefix(Self.shown)), id: \.index) { file in
                    FileResultRow(file: file, torrent: torrent)
                }
                if problems.count > Self.shown {
                    Button(showsAll ? "Show Fewer" : "Show \(problems.count - Self.shown) More") {
                        withAnimation(.snappy) { showsAll.toggle() }
                    }
                    .buttonStyle(.link)
                    .padding(.leading, 22)
                }
                if passed > 0 {
                    HStack(spacing: 6) {
                        CheckStatusIcon(status: .passed, size: 12)
                        Text("\(Format.count(passed, "other file")) passed")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .font(.callout)
            .padding(.top, 1)
        }
    }
}

/// One file a check found something about.
private struct FileResultRow: View {
    let file: CheckRecord.FileResult
    let torrent: Torrent

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            CheckStatusIcon(status: file.status, size: 12)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(file.path)
                if let summary = file.summary {
                    Text(summary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            Spacer(minLength: 6)
            // Before it downloads, there's nothing to show.
            if FileActions.exists(URL(fileURLWithPath: torrent.savePath).appending(path: file.path)) {
                Button {
                    FileActions.reveal(paths: [file.path], of: torrent)
                } label: {
                    Image(systemName: "folder")
                        .frame(width: 18, height: 18)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Show in Finder")
                .accessibilityLabel("Show \(file.name) in Finder")
            }
            if let link = file.link {
                ReportLink(link: link)
            }
        }
    }
}

/// The files a check added next to the download's, by name.
private struct AddedFilesList: View {
    let paths: [String]
    private static let shown = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(paths.prefix(Self.shown), id: \.self) { path in
                Label((path as NSString).lastPathComponent, systemImage: "doc.badge.plus")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
            }
            if paths.count > Self.shown {
                Text("and \(paths.count - Self.shown) more")
                    .padding(.leading, 22)
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.top, 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Added \(paths.count == 1 ? "a file" : "\(paths.count) files")")
    }
}

/// A check's result as a word in a tinted capsule.
private struct StatusChip: View {
    let status: CheckRecord.Status

    var body: some View {
        Text(status.title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(status.isFinished && status != .skipped ? AnyShapeStyle(status.tint) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(status.isFinished && status != .skipped ? AnyShapeStyle(status.tint.opacity(0.15)) : AnyShapeStyle(.quaternary),
                        in: .capsule)
            .fixedSize()
    }
}

/// A hook that's on but hasn't run on this download.
private struct UpcomingCard: View {
    @Environment(AppModel.self) private var model
    let upcoming: CheckSummary.Upcoming
    let torrent: Torrent

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ExtensionCheckIcon(extensionName: upcoming.item.name, status: .queued, size: 30)
                .opacity(0.55)
            VStack(alignment: .leading, spacing: 2) {
                Text(upcoming.item.title)
                    .fontWeight(.medium)
                Text(upcoming.runsLater ? "Runs once the download finishes" : "Hasn't run on this download")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if !upcoming.runsLater {
                Button("Run Now") { Task { await model.extensions.runAgain(upcoming.item, upcoming.hook, on: torrent) } }
                    .buttonStyle(.link)
                    .font(.callout)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }
}

/// A check's result as a ring with its mark, the same design as a
/// download's check ring, for lists and tables.
struct CheckStatusIcon: View {
    let status: CheckRecord.Status
    var size: CGFloat = 14
    /// What hovering over it says, if more than the status.
    var help: String?

    var body: some View {
        let line = CheckMark.lineWidth(for: size)
        ZStack {
            if status == .running {
                Circle()
                    .stroke(.quaternary, lineWidth: line)
                    .padding(line / 2)
                CheckSpinner(lineWidth: line)
            } else {
                Circle()
                    .stroke(color, lineWidth: line)
                    .padding(line / 2)
                if let mark = status.mark {
                    CheckMark(kind: mark)
                        .stroke(color, style: CheckMark.style(line))
                }
            }
        }
        .frame(width: size, height: size)
        .frame(width: max(size, 16))
        .help(help ?? status.title)
    }

    private var color: AnyShapeStyle {
        status.isFinished && status != .skipped ? AnyShapeStyle(status.tint) : AnyShapeStyle(.secondary)
    }
}

extension CheckRecord.Status {
    var title: String {
        switch self {
        case .queued: "Waiting"
        case .running: "Checking"
        case .passed: "Passed"
        case .warning: "Warning"
        case .failed: "Failed"
        case .skipped: "Skipped"
        case .didNotFinish: "Didn't finish"
        }
    }
}

/// The markdown extensions write: headings, paragraphs, and "- " and "1. "
/// lists, with bold, code and links inside them. Lines wrapped by hand join up,
/// as in any markdown.
struct MarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(Self.blocks(of: text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let line):
                    Text(Self.inline(line))
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)
                case .paragraph(let line):
                    Text(Self.inline(line))
                        .fixedSize(horizontal: false, vertical: true)
                case .item(let marker, let line):
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(marker)
                            .monospacedDigit()
                        Text(Self.inline(line))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .textSelection(.enabled)
    }

    enum Block: Equatable {
        case heading(String), paragraph(String), item(marker: String, text: String)
    }

    nonisolated static func blocks(of text: String) -> [Block] {
        var blocks: [Block] = []
        /// Whether the next line carries on the last block.
        var isOpen = false
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                isOpen = false
            } else if trimmed.hasPrefix("#") {
                blocks.append(.heading(trimmed.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression)))
                isOpen = false
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                blocks.append(.item(marker: "•", text: String(trimmed.dropFirst(2))))
                isOpen = true
            } else if let number = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                blocks.append(.item(marker: trimmed[number].trimmingCharacters(in: .whitespaces),
                                    text: String(trimmed[number.upperBound...])))
                isOpen = true
            } else if isOpen, let last = blocks.popLast() {
                switch last {
                case .paragraph(let text): blocks.append(.paragraph(text + " " + trimmed))
                case .item(let marker, let text): blocks.append(.item(marker: marker, text: text + " " + trimmed))
                case .heading: blocks += [last, .paragraph(trimmed)]
                }
            } else {
                blocks.append(.paragraph(trimmed))
                isOpen = true
            }
        }
        return blocks
    }

    private static func inline(_ line: String) -> AttributedString {
        (try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(line)
    }
}
