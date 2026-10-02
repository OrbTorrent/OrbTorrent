import AppKit
import SwiftUI

/// The first-run welcome, one step at a time: the orb filling with light,
/// bringing over another app's downloads when this Mac has some, and
/// finishing setup. The orb stays on screen throughout, moving to its place
/// in each step.
struct WelcomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = Step.welcome
    @State private var imports = WelcomeImport()
    /// How full the orb is as it first fills with light, 0...1.
    @State private var fill = 0.0
    @State private var reveal = Reveal.nothing
    /// The glow swelling as the orb fills to the top.
    @State private var isGlowSwelling = false
    @State private var isContinuing = false
    @State private var hasOfferedImport = false
    /// The app whose detailed import sheet is open.
    @State private var choosing: ImportSource?

    private enum Step { case welcome, bringOver, finish }

    /// How far the welcome has shown itself, in order.
    private enum Reveal: Int { case nothing, orb, title, subtitle, everything }

    private static let size = CGSize(width: 600, height: 600)
    /// The orb is drawn at this size and scaled to each step's.
    private static let orbSize: CGFloat = 172

    var body: some View {
        ZStack(alignment: .top) {
            backdrop
            if step == .bringOver, let offer = imports.offer {
                ImportFlow(sources: offer.sources, chosen: imports.chosen, speed: flowSpeed,
                           isFlowing: !imports.phase.isFinished, iconCenters: iconCenters(offer.sources.count),
                           orbCenter: orbCenter, orbRadius: orbDiameter / 2)
                    .transition(StepTransition())
            }
            orb
            content
            footer
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .onAppear {
            model.defaultApp.refresh()
            model.loginItem.refresh()
        }
        .task { await playIntro() }
        // Settings are compared once the engine reports its own.
        .task(id: model.preferences == nil) { await imports.load(from: model) }
        .task { await imports.watchRunning() }
        .sheet(item: $choosing, onDismiss: {
            Task { await imports.load(from: model, afterChoosing: true) }
        }) { source in
            ImportSheet(source: source)
        }
    }

    // MARK: Orb

    private var orbCenter: CGPoint {
        switch step {
        case .welcome: CGPoint(x: 300, y: 214)
        case .bringOver: CGPoint(x: 400, y: 124 + bringOverDrop)
        case .finish: CGPoint(x: 300, y: 132)
        }
    }

    private var orbDiameter: CGFloat {
        switch step {
        case .welcome: Self.orbSize
        case .bringOver: 104
        case .finish: 88
        }
    }

    /// How far the bring-over step sits lower with one app than with two,
    /// so it stays centred above the buttons.
    private var bringOverDrop: CGFloat {
        imports.offer.map { $0.findings.count > 1 ? 0 : 44 } ?? 0
    }

    /// Where each app's icon sits, across from the orb.
    private func iconCenters(_ count: Int) -> [CGPoint] {
        let y = orbCenter.y, spacing: CGFloat = 76
        return (0..<count).map { CGPoint(x: 196, y: y + (CGFloat($0) - CGFloat(count - 1) / 2) * spacing) }
    }

    private var orb: some View {
        let isShown = shows(.orb)
        return LiveOrb(state: orbState, turnSpeed: turnSpeed)
            .frame(width: Self.orbSize, height: Self.orbSize)
            .scaleEffect(orbDiameter / Self.orbSize * (isShown ? 1 : 0.8))
            .opacity(isShown ? 1 : 0)
            .blur(radius: isShown ? 0 : 14)
            .position(orbCenter)
            .animation(.spring(duration: 0.9, bounce: 0.18), value: step)
    }

    private var orbState: OrbState {
        switch step {
        case .welcome:
            fill < 1 ? .downloading(progress: fill, energy: 0.8) : .idle
        case .bringOver:
            switch imports.phase {
            case .importing: .downloading(progress: 1, energy: 1)
            case .finished: .finished
            default: .idle
            }
        case .finish:
            // Green, as a finished download is: everything's ready.
            .finished
        }
    }

    /// The globe spins up as it fills, and while downloads come over.
    private var turnSpeed: Double {
        switch step {
        case .welcome: fill < 1 ? 5 : 1.5
        case .bringOver: imports.phase == .importing ? 4 : 1
        case .finish: 1
        }
    }

    private var flowSpeed: Double {
        imports.phase == .importing ? 1.3 : 0.3
    }

    /// A soft glow in the orb's colour behind everything, which follows the
    /// orb and turns green once downloads have come over, and at the end.
    private var backdrop: some View {
        let isDone = step == .finish || (step == .bringOver && imports.phase.isFinished)
        let strength = step == .welcome ? 0.25 + 0.75 * fill : 1
        return ZStack {
            Circle()
                .fill(isDone ? OrbPalette.finished.glow : OrbPalette.active.glow)
                .frame(width: 400, height: 400)
                .blur(radius: 90)
                .opacity(0.3 * strength * (isGlowSwelling ? 1.4 : 1))
                .scaleEffect(isGlowSwelling ? 1.2 : 1)
                .position(orbCenter)
            Circle()
                .fill((isDone ? OrbPalette.finished : OrbPalette.active).veils[1])
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .opacity(0.14 * strength)
                .position(x: orbCenter.x - 130, y: orbCenter.y + 110)
        }
        .animation(.smooth(duration: 1.1), value: step)
        .animation(.smooth(duration: 1), value: isDone)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome:
            welcome
                .transition(StepTransition())
        case .bringOver:
            if let offer = imports.offer {
                bringOver(offer)
                    .transition(StepTransition())
            }
        case .finish:
            finish
                .transition(StepTransition())
        }
    }

    private var welcome: some View {
        VStack(spacing: 10) {
            Text("Welcome to OrbTorrent")
                .font(.system(size: 32, weight: .bold))
                .revealed(shows(.title))
            Text("A fast, native torrent app for your Mac, powered by qBittorrent.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .revealed(shows(.subtitle))
        }
        .padding(.top, 342)
        .padding(.horizontal, 40)
    }

    private func bringOver(_ offer: ImportOffer) -> some View {
        VStack(spacing: 0) {
            Text(bringOverTitle(offer))
                .font(.title.weight(.bold))
                .contentTransition(.opacity)
            Text(bringOverSubtitle(offer))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
                .frame(maxWidth: 460)
                .padding(.top, 8)
            ImportChoices(imports: imports, offer: offer) { choosing = $0 }
                .frame(width: 468)
                .padding(.top, 22)
        }
        .padding(.top, 206 + bringOverDrop)
    }

    private func bringOverTitle(_ offer: ImportOffer) -> String {
        if imports.phase.isFinished { return "You're all moved in" }
        return offer.findings.contains { $0.downloads > 0 } ? "Bring your downloads over" : "Bring your settings over"
    }

    private func bringOverSubtitle(_ offer: ImportOffer) -> String {
        guard case .finished(let imported) = imports.phase else {
            let names = ListFormatter.localizedString(byJoining: offer.sources.map(\.name))
            return offer.findings.contains { $0.downloads > 0 }
                ? "OrbTorrent found \(names) on this Mac. Your downloads pick up right where they left off."
                : "OrbTorrent found \(names) on this Mac. Your settings from there can come with you."
        }
        guard let imported else { return "Everything is in OrbTorrent now." }
        let downloads = imported.values.reduce(0, +), settings = imports.settingsCount
        guard downloads > 0 || settings > 0 else { return "There was nothing new to bring over." }
        var text = "\(ImportOffer.summary(downloads: downloads, settings: settings)) came over."
        if (imported[.transmission] ?? 0) > 0 {
            text += " OrbTorrent checks the files from Transmission first, and each download carries on as it was."
        }
        return text
    }

    private var finish: some View {
        VStack(spacing: 0) {
            Text("Finish setting up")
                .font(.title.weight(.bold))
            if AppIdentity.isDevelopment {
                Text(AppIdentity.developmentNote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 440)
                    .padding(.top, 8)
            } else {
                Text("You can change these any time in Settings.")
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                setupRows
            }
        }
        .padding(.top, 204)
    }

    private var setupRows: some View {
        VStack(spacing: 0) {
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    row(symbol: "link", title: "Open torrents with OrbTorrent",
                        detail: "Magnet links and .torrent files open here and start downloading.") {
                        if model.defaultApp.isDefault {
                            Label("Done", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.callout.weight(.medium))
                                .transition(.scale(scale: 0.6).combined(with: .opacity))
                        } else {
                            Button("Make Default") {
                                Task {
                                    try? await model.defaultApp.makeDefault()
                                }
                            }
                            .buttonStyle(.glass)
                        }
                    }
                    .animation(.smooth, value: model.defaultApp.isDefault)
                    row(symbol: "power", title: "Start at login",
                        detail: "OrbTorrent waits quietly in the menu bar so downloads resume on their own.") {
                        Toggle("Start at login", isOn: Binding(
                            get: { model.loginItem.isEnabled },
                            set: { try? model.loginItem.setEnabled($0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                    }
                }
            }
            .frame(width: 468)
            .padding(.top, 22)
        }
    }

    private func row<Accessory: View>(symbol: String, title: String, detail: String,
                                      @ViewBuilder accessory: () -> Accessory) -> some View {
        HStack(spacing: 14) {
            TorrentIcon(symbol: symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            accessory()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                if step == .bringOver, imports.phase == .choosing || imports.phase.isFailure {
                    Button { go(to: .finish) } label: {
                        Text("Not Now")
                            .frame(minWidth: 90)
                    }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                    .transition(.opacity)
                }
                primaryButton
            }
            .controlSize(.extraLarge)
            pageDots
        }
        .padding(.bottom, 24)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .revealed(shows(.everything))
        .disabled(!shows(.everything))
        .animation(.smooth, value: imports.phase)
    }

    private var primaryButton: some View {
        let (title, isWorking, action) = primaryAction
        return Button(action: action) {
            HStack(spacing: 8) {
                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(title)
                    .contentTransition(.opacity)
            }
            .frame(minWidth: 160)
        }
        .buttonStyle(.glassProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(isWorking || (step == .bringOver && imports.phase == .choosing && imports.chosen.isEmpty))
    }

    private var primaryAction: (title: String, isWorking: Bool, action: () -> Void) {
        switch step {
        case .welcome:
            return ("Continue", isContinuing, { Task { await continueFromWelcome() } })
        case .bringOver:
            let bringOver = { Task { await imports.run(with: model) } }
            switch imports.phase {
            case .choosing:
                let quitting = imports.quitting
                let title = switch quitting.count {
                case 0: "Import"
                case 1: "Quit \(quitting[0].name) and Import"
                default: "Quit Both and Import"
                }
                return (title, false, { _ = bringOver() })
            case .importing:
                return (imports.quitting.isEmpty ? "Importing…" : "Waiting to Quit…", true, {})
            case .finished:
                return ("Continue", false, { go(to: .finish) })
            case .failed:
                return ("Try Again", false, { _ = bringOver() })
            }
        case .finish:
            return ("Get Started", false, complete)
        }
    }

    private var steps: [Step] {
        let offersImport = hasOfferedImport || imports.offer.map { !$0.isEmpty } ?? !model.importSources.isEmpty
        return offersImport ? [.welcome, .bringOver, .finish] : [.welcome, .finish]
    }

    private var pageDots: some View {
        HStack(spacing: 7) {
            ForEach(steps, id: \.self) { each in
                Capsule()
                    .fill(.primary.opacity(each == step ? 0.65 : 0.18))
                    .frame(width: each == step ? 20 : 7, height: 7)
            }
        }
        .animation(.spring(duration: 0.5, bounce: 0.25), value: step)
        .accessibilityHidden(true)
    }

    // MARK: Actions

    private func shows(_ stage: Reveal) -> Bool {
        reveal.rawValue >= stage.rawValue
    }

    /// The orb fades in empty and fills with light as its globe spins up,
    /// then the words and buttons follow.
    private func playIntro() async {
        guard !reduceMotion else {
            fill = 1
            reveal = .everything
            return
        }
        withAnimation(.smooth(duration: 1.1)) { reveal = .orb }
        try? await Task.sleep(for: .milliseconds(350))
        let start = ContinuousClock.now, duration = Duration.seconds(2.6)
        while fill < 1, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(16))
            let t = min(1, (ContinuousClock.now - start) / duration)
            // Eased in and out, so the light rises smoothly and settles.
            fill = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            if t > 0.45, !shows(.title) {
                withAnimation(.smooth(duration: 1.1)) { reveal = .title }
            }
            if t > 0.62, !shows(.subtitle) {
                withAnimation(.smooth(duration: 1.1)) { reveal = .subtitle }
            }
        }
        withAnimation(.easeOut(duration: 0.5)) { isGlowSwelling = true }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.smooth(duration: 1.4)) { isGlowSwelling = false }
        withAnimation(.smooth(duration: 0.9)) { reveal = .everything }
    }

    /// Moves on once it's known what the other apps have, waiting a few
    /// seconds at most for the engine to report its settings.
    private func continueFromWelcome() async {
        isContinuing = true
        let deadline = ContinuousClock.now + .seconds(4)
        while !imports.isReady, !model.importSources.isEmpty, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
        isContinuing = false
        if imports.offer?.isEmpty == false {
            hasOfferedImport = true
            go(to: .bringOver)
        } else {
            go(to: .finish)
        }
    }

    private func go(to next: Step) {
        withAnimation(.smooth(duration: 0.7)) { step = next }
    }

    private func complete() {
        model.settings.hasCompletedOnboarding = true
        dismiss()
    }
}

/// A step coming in from the right as the last one leaves to the left,
/// each softly blurred as it moves.
private struct StepTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 8)
            .offset(x: phase == .willAppear ? 40 : phase == .didDisappear ? -40 : 0)
    }
}

private extension View {
    /// Fades in from a soft blur, rising a little into place.
    func revealed(_ isShown: Bool) -> some View {
        opacity(isShown ? 1 : 0)
            .blur(radius: isShown ? 0 : 8)
            .offset(y: isShown ? 0 : 12)
    }
}
