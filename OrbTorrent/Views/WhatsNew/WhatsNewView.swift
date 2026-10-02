import SwiftUI

/// What's new in the version just installed, from its release notes on
/// GitHub. Shown once in the main window after an update, and from the Help
/// menu. The orb greets it, as in the welcome, and each part of the notes
/// rises into place after it.
///
/// The whole page scrolls. As the orb and title scroll away, they shrink and
/// fade, and a slim bar with a small orb and the title takes their place.
/// The buttons stay at the bottom, the notes passing softly under them.
struct WhatsNewView: View {
    /// Newest first: more than one after skipping updates.
    let releases: [Release]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var reveal = Reveal.nothing
    /// How many cards have risen into place.
    @State private var shownCards = 0
    @State private var turnSpeed = 1.0
    /// How far the page has scrolled.
    @State private var offset: CGFloat = 0
    @State private var pageHeight: CGFloat = 0
    @State private var barsHeight = Bars()

    private enum Reveal: Int { case nothing, orb, title, notes, everything }

    private struct Bars: Equatable {
        var top: CGFloat = 0
        var bottom: CGFloat = 0
    }

    private static let width: CGFloat = 560
    private static let orbSize: CGFloat = 84
    /// Longer notes scroll.
    private static let maxHeight: CGFloat = 600
    /// The notes fade out over this much above the buttons, and end this far
    /// above them too, so the last of them scrolls fully into view.
    private static let bottomFade: CGFloat = 24
    /// How far the page scrolls before the title has gone under the bar.
    private static let collapseDistance: CGFloat = 150

    private var parts: [(release: Release, sections: [ReleaseNotesDocument.Section])] {
        releases.map { ($0, ReleaseNotesDocument(markdown: $0.notes).sections) }
    }

    /// 0 with the header in full, 1 once it has scrolled away.
    private var collapse: CGFloat {
        min(max(offset / Self.collapseDistance, 0), 1)
    }

    private var isCollapsed: Bool { collapse > 0.85 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                notes
            }
            .background(alignment: .top) { backdrop }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { pageHeight = $0 }
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in
            offset = new
        }
        .scrollBounceBehavior(.basedOnSize)
        // The notes fade out under the header and buttons instead, without
        // a band drawn across the sheet.
        .scrollEdgeEffectHidden(true, for: .all)
        .mask { fadeUnderBars }
        // Over the page, so the orb and its glow start right at the top.
        .overlay(alignment: .top) {
            compactHeader
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barsHeight.top = $0 }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            footer
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { barsHeight.bottom = $0 }
        }
        .frame(width: Self.width, height: min(pageHeight + barsHeight.bottom, Self.maxHeight))
        .onExitCommand { dismiss() }
        .task { await playIntro() }
    }

    /// The notes fade out as they near the buttons, and under the slim bar
    /// once the header has scrolled away.
    private var fadeUnderBars: some View {
        VStack(spacing: 0) {
            LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: .black, location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: isCollapsed ? barsHeight.top + 16 : 0)
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: Self.bottomFade)
        }
        .animation(.smooth(duration: 0.35), value: isCollapsed)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            LiveOrb(state: .idle, turnSpeed: turnSpeed)
                .frame(width: Self.orbSize, height: Self.orbSize)
                .frame(height: Self.orbSize * 1.2)
                .scaleEffect(shows(.orb) ? 1 : 0.8)
                .opacity(shows(.orb) ? 1 : 0)
                .blur(radius: shows(.orb) ? 0 : 14)
                // Shrinking towards the bar as it scrolls away.
                .scaleEffect(1 - 0.4 * collapse, anchor: .bottom)
                .opacity(1 - collapse)

            VStack(spacing: 4) {
                Text("What's New in \(AppIdentity.name)")
                    .font(.system(size: 26, weight: .bold))
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .revealed(shows(.title))
            .scaleEffect(1 - 0.15 * collapse)
            .opacity(1 - collapse)
        }
        .padding(.top, 30)
        .padding(.horizontal, 32)
    }

    /// The small orb and title the header becomes once it has scrolled away.
    private var compactHeader: some View {
        HStack(spacing: 10) {
            LiveOrb(state: .idle)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("What's New in \(AppIdentity.name)")
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .opacity(isCollapsed ? 1 : 0)
        .offset(y: isCollapsed ? 0 : 8)
        .animation(.smooth(duration: 0.35), value: isCollapsed)
        .allowsHitTesting(false)
        .accessibilityHidden(!isCollapsed)
    }

    /// Such as "Version 1.0 beta 2 · 29 September 2026".
    private var subtitle: String {
        guard let newest = releases.first else { return "" }
        return (["Version \(newest.name)"] + [newest.date?.formatted(date: .long, time: .omitted)].compactMap(\.self))
            .joined(separator: " · ")
    }

    // MARK: Notes

    private var notes: some View {
        VStack(alignment: .leading, spacing: 14) {
            let parts = parts
            ForEach(parts.indices, id: \.self) { index in
                let part = parts[index]
                if index > 0 {
                    earlierHeading(part.release)
                        .revealed(shownCards > cardIndex(part: index, section: 0))
                }
                ForEach(part.sections.indices, id: \.self) { section in
                    SectionCard(section: part.sections[section])
                        .revealed(shownCards > cardIndex(part: index, section: section))
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, Self.bottomFade + 8)
    }

    /// Where an earlier release's notes begin, after skipping updates.
    private func earlierHeading(_ release: Release) -> some View {
        HStack(spacing: 10) {
            Text("Also new since \(release.name)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
            VStack { Divider() }
        }
        .padding(.top, 10)
    }

    /// The order a card rises in, counting every release's sections.
    private func cardIndex(part: Int, section: Int) -> Int {
        parts.prefix(part).reduce(0) { $0 + $1.sections.count } + section
    }

    private var cardCount: Int {
        parts.reduce(0) { $0 + $1.sections.count }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if let link = releases.first?.link {
                Button { openURL(link) } label: {
                    Text(link.host() == "github.com" ? "View on GitHub" : "Learn More")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.glass)
            }
            Button { dismiss() } label: {
                Text("Continue")
                    .frame(minWidth: 140)
            }
            .buttonStyle(.glassProminent)
            .keyboardShortcut(.defaultAction)
        }
        .controlSize(.extraLarge)
        .padding(.top, 4)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .revealed(shows(.everything))
    }

    /// A soft glow in the orb's colour behind the top of the sheet.
    private var backdrop: some View {
        ZStack {
            Circle()
                .fill(OrbPalette.active.glow)
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .opacity(shows(.orb) ? 0.32 : 0)
                .offset(y: -140)
            Circle()
                .fill(OrbPalette.active.veils[1])
                .frame(width: 240, height: 240)
                .blur(radius: 80)
                .opacity(shows(.orb) ? 0.14 : 0)
                .offset(x: -170, y: -10)
        }
        .frame(width: Self.width)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: Motion

    private func shows(_ stage: Reveal) -> Bool {
        reveal.rawValue >= stage.rawValue
    }

    /// The orb spins up as it appears and coasts back to its usual pace,
    /// while the title and then each card follow.
    private func playIntro() async {
        guard !reduceMotion else {
            reveal = .everything
            shownCards = cardCount
            return
        }
        turnSpeed = 6
        withAnimation(.spring(duration: 0.9, bounce: 0.2)) { reveal = .orb }
        try? await Task.sleep(for: .milliseconds(260))
        withAnimation(.smooth(duration: 0.8)) { reveal = .title }
        try? await Task.sleep(for: .milliseconds(240))
        reveal = .notes
        for card in 0..<cardCount {
            withAnimation(.smooth(duration: 0.7)) { shownCards = card + 1 }
            try? await Task.sleep(for: .milliseconds(110))
        }
        withAnimation(.smooth(duration: 0.7)) { reveal = .everything }
        try? await Task.sleep(for: .milliseconds(500))
        turnSpeed = 1
    }
}

/// One part of the notes, such as "New" or "Fixed", in a glass card.
private struct SectionCard: View {
    let section: ReleaseNotesDocument.Section

    var body: some View {
        let kind = section.kind
        VStack(alignment: .leading, spacing: 12) {
            if let title = section.title {
                HStack(spacing: 10) {
                    TorrentIcon(symbol: kind.symbol, tint: kind.tint, size: 30)
                    Text(title)
                        .font(.headline)
                }
            }
            VStack(alignment: .leading, spacing: 11) {
                ForEach(section.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        if let title = item.title {
                            Text(title)
                                .font(.callout.weight(.semibold))
                        }
                        Text(item.text)
                            .font(.callout)
                            .foregroundStyle(item.title == nil ? .primary : .secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                }
            }
            // In line with the heading, after its icon.
            .padding(.leading, section.title == nil ? 0 : 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }
}

extension ReleaseNotesDocument.Kind {
    var symbol: String {
        switch self {
        case .new: "sparkles"
        case .improved: "wand.and.stars"
        case .fixed: "checkmark.seal"
        case .issues: "exclamationmark.triangle"
        case .other: "text.bubble"
        }
    }

    var tint: Color {
        switch self {
        case .new: .accentColor
        case .improved: .purple
        case .fixed: .green
        case .issues: .orange
        case .other: .teal
        }
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
