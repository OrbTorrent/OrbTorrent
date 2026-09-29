import AppKit
import SwiftUI

/// The welcome's offer to bring over other apps' downloads and settings,
/// and how bringing them over goes.
@MainActor @Observable
final class WelcomeImport {
    enum Phase: Equatable {
        case choosing
        case importing
        /// How many downloads came over from each app, or nil when they came
        /// over through the detailed import sheet instead.
        case finished([ImportSource: Int]?)
        case failed(String)
    }

    private(set) var offer: ImportOffer?
    /// Whether the offer includes settings, which are compared once the
    /// engine reports its own.
    private(set) var hasSettings = false
    var chosen: Set<ImportSource> = []
    /// The offered apps that are open right now.
    private(set) var running: Set<ImportSource> = []
    private(set) var phase = Phase.choosing
    /// The apps offered so far, so a later look doesn't switch one back on.
    private var offered: Set<ImportSource> = []

    var isReady: Bool { offer != nil && hasSettings }

    /// Looks at what each app has. After an import from the detailed sheet,
    /// an app with nothing left drops out, and once none is left the import
    /// counts as done.
    func load(from model: AppModel, afterChoosing: Bool = false) async {
        let comparesSettings = model.preferences != nil
        // A look without settings has less to say than one already made.
        if hasSettings && !comparesSettings { return }
        let fresh = ImportOffer(await model.importFindings())
        guard phase == .choosing || phase.isFailure else { return }
        hasSettings = comparesSettings
        if afterChoosing, fresh.isEmpty, offer?.isEmpty == false {
            withAnimation(.smooth(duration: 0.6)) { phase = .finished(nil) }
            return
        }
        let sources = Set(fresh.sources)
        chosen = chosen.intersection(sources).union(sources.subtracting(offered))
        offered.formUnion(sources)
        withAnimation(.smooth) { offer = fresh }
    }

    /// Keeps track of which offered apps are open, since they quit to import.
    func watchRunning() async {
        while !Task.isCancelled {
            let open = Set((offer?.sources ?? []).filter(\.isRunning))
            if open != running { running = open }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    func run(with model: AppModel) async {
        guard let offer else { return }
        withAnimation(.smooth) { phase = .importing }
        let started = ContinuousClock.now
        do {
            let imported = try await model.runImport(offer.jobs(for: chosen))
            // Long enough to see the downloads flow into the orb.
            try? await Task.sleep(until: started + .seconds(1.6))
            withAnimation(.smooth(duration: 0.6)) { phase = .finished(imported) }
        } catch {
            withAnimation(.smooth) { phase = .failed(error.localizedDescription) }
        }
    }

    /// The offered apps that quit when the import starts.
    var quitting: [ImportSource] {
        (offer?.sources ?? []).filter { chosen.contains($0) && running.contains($0) }
    }

    /// How many settings come over, or came over.
    var settingsCount: Int {
        guard let offer else { return 0 }
        return offer.findings.filter { chosen.contains($0.source) }.map { offer.settings(from: $0).count }.reduce(0, +)
    }
}

extension WelcomeImport.Phase {
    var isFailure: Bool {
        if case .failed = self { true } else { false }
    }

    var isFinished: Bool {
        if case .finished = self { true } else { false }
    }
}

// MARK: - Flow

/// Downloads flowing from the other apps into the orb, as a stream of
/// light from each app's icon.
struct ImportFlow: View {
    let sources: [ImportSource]
    let chosen: Set<ImportSource>
    /// How fast the light flows, in trips per second.
    let speed: Double
    /// Whether any light flows; it fades out once the import is done.
    let isFlowing: Bool
    /// Where each app's icon sits, in order.
    let iconCenters: [CGPoint]
    let orbCenter: CGPoint
    let orbRadius: CGFloat

    @State private var motion = FlowMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let iconSize: CGFloat = 60
    private static let start = OrbPalette.active.veils[0]
    private static let end = OrbPalette.active.veils[2]

    var body: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
                let phase = motion.advance(to: timeline.date, speed: speed)
                ZStack {
                    ForEach(Array(sources.enumerated()), id: \.element) { index, source in
                        Canvas { context, _ in
                            drawStream(in: &context, from: iconCenters[index], phase: phase + Double(index) * 0.37)
                        }
                        .opacity(chosen.contains(source) && isFlowing ? 1 : 0)
                    }
                }
            }
            ForEach(Array(sources.enumerated()), id: \.element) { index, source in
                icon(for: source)
                    .position(iconCenters[index])
            }
        }
        .animation(.smooth(duration: 0.5), value: chosen)
        .animation(.smooth(duration: 0.9), value: isFlowing)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func icon(for source: ImportSource) -> some View {
        let isChosen = chosen.contains(source)
        return Group {
            if let image = source.icon {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
            } else {
                TorrentIcon(symbol: "arrow.down.circle", size: Self.iconSize)
            }
        }
        .frame(width: Self.iconSize, height: Self.iconSize)
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .saturation(isChosen ? 1 : 0)
        .opacity(isChosen ? 1 : 0.45)
        .scaleEffect(isChosen ? 1 : 0.9)
    }

    /// A faint path from the icon to the orb's edge, curving in when the
    /// icon sits above or below the orb, with beads of light travelling it.
    private func drawStream(in context: inout GraphicsContext, from icon: CGPoint, phase: Double) {
        let start = CGPoint(x: icon.x + Self.iconSize / 2 + 12, y: icon.y)
        let end = CGPoint(x: orbCenter.x - orbRadius * 0.94, y: orbCenter.y + (icon.y - orbCenter.y) * 0.3)
        let control = CGPoint(x: (start.x + end.x) / 2, y: icon.y)
        func point(_ t: Double) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
                           y: u * u * start.y + 2 * u * t * control.y + t * t * end.y)
        }

        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        context.stroke(path, with: .linearGradient(
            Gradient(stops: [
                .init(color: Self.start.opacity(0), location: 0),
                .init(color: Self.start.opacity(0.35), location: 0.35),
                .init(color: Self.end.opacity(0.35), location: 0.75),
                .init(color: Self.end.opacity(0), location: 1),
            ]),
            startPoint: start, endPoint: end), lineWidth: 1)

        let beads = 7
        for bead in 0..<beads {
            let turn = phase + Double(bead) / Double(beads)
            let t = turn - turn.rounded(.down)
            let swell = sin(.pi * t)
            let radius = 1.8 + 1.8 * swell
            let color = Self.start.mix(with: Self.end, by: t)
            let p = point(t)
            var halo = context
            halo.addFilter(.blur(radius: radius * 1.4))
            halo.fill(Circle().path(in: CGRect(x: p.x - radius * 2.4, y: p.y - radius * 2.4, width: radius * 4.8, height: radius * 4.8)),
                      with: .color(color.opacity(0.6 * swell)))
            context.fill(Circle().path(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(color.mix(with: .white, by: 0.4).opacity(swell)))
        }
    }
}

/// Moves the flow along, easing between speeds so it gathers pace and settles.
@MainActor
private final class FlowMotion {
    private var phase = 0.0
    private var speed: Double?
    private var lastDate: Date?

    func advance(to date: Date, speed target: Double) -> Double {
        let dt = min(max(date.timeIntervalSince(lastDate ?? date), 0), 0.1)
        lastDate = date
        var speed = self.speed ?? target
        speed += (target - speed) * (1 - exp(-dt / 0.6))
        self.speed = speed
        phase += dt * speed
        return phase
    }
}

// MARK: - Choices

/// Each app to bring over, with a switch, and what came over once it's done.
struct ImportChoices: View {
    let imports: WelcomeImport
    let offer: ImportOffer
    /// Opens the detailed import for one app.
    let choose: (ImportSource) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    ForEach(offer.findings) { finding in
                        card(for: finding)
                    }
                }
            }
            notes
                .padding(.horizontal, 4)
        }
    }

    private func card(for finding: ImportFinding) -> some View {
        let source = finding.source
        return HStack(spacing: 12) {
            Group {
                if let image = source.icon {
                    Image(nsImage: image)
                        .resizable()
                        .interpolation(.high)
                } else {
                    TorrentIcon(symbol: "arrow.down.circle", size: 36)
                }
            }
            .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.callout.weight(.semibold))
                Text(detail(for: finding))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer(minLength: 12)
            switch imports.phase {
            case .finished:
                if imports.chosen.contains(source) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            default:
                Button("Choose…") { choose(source) }
                    .buttonStyle(.borderless)
                    .disabled(imports.phase == .importing)
                Toggle("Bring over \(source.name)", isOn: Binding(
                    get: { imports.chosen.contains(source) },
                    set: { isOn in
                        if isOn { imports.chosen.insert(source) } else { imports.chosen.remove(source) }
                    }
                ).animation(.smooth))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(imports.phase == .importing)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    private func detail(for finding: ImportFinding) -> String {
        guard case .finished(let imported) = imports.phase else { return offer.summary(of: finding) }
        guard imports.chosen.contains(finding.source) else { return "Not brought over" }
        guard let imported else { return "In OrbTorrent now" }
        let downloads = imported[finding.source] ?? 0, settings = offer.settings(from: finding).count
        if downloads == 0 && settings == 0 { return "Nothing new to bring over" }
        return "Brought over \(ImportOffer.summary(downloads: downloads, settings: settings))"
    }

    @ViewBuilder
    private var notes: some View {
        VStack(alignment: .leading, spacing: 6) {
            if case .failed(let message) = imports.phase {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .symbolRenderingMode(.multicolor)
            }
            if !imports.phase.isFinished {
                if offer.leavesSettingsBehind, let source = offer.settingsSource {
                    Label("Settings come from \(source.name), the app you used most recently.", systemImage: "slider.horizontal.3")
                }
                let quitting = imports.quitting
                if !quitting.isEmpty {
                    Label(quitting.count == 1
                          ? "\(quitting[0].name) quits when you import, so the two apps don't use the same files."
                          : "\(ListFormatter.localizedString(byJoining: quitting.map(\.name))) quit when you import, so the apps don't use the same files.",
                          systemImage: "info.circle")
                }
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}
