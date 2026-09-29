import SwiftUI

/// Everything that decides how the orb looks at one moment.
struct OrbAppearance {
    /// How full the orb is with light, 0...1.
    var level: Double = 1
    /// Accumulated motion time; it advances faster when the orb is busier.
    var phase: Double = 0
    /// How lively the light is, 0...1.
    var energy: Double = 0.5
    var saturation: Double = 1
    var palette: OrbPalette = .active
    /// Extra glow, 0...1: seeding's breathing and the flash on finishing.
    var bloom: Double = 0
    /// How far the globe has turned, in radians.
    var spin: Double = 0
}

/// Turns state changes into smooth motion: the level eases, colours blend,
/// the flow speeds up or settles, the globe keeps turning, and finishing
/// flashes the glow.
///
/// `LiveOrb` advances it once per frame.
@MainActor
final class OrbMotion {
    private var level: Double = 1
    private var energy: Double = 0.35
    private var saturation: Double = 1
    private var rate: Double = 0.3
    private var bloom: Double = 0
    private var phase: Double
    private var palette = ResolvedPalette(.active)
    private var lastDate: Date?
    private var lastState: OrbState?
    private var flashStart: Date?
    private var clock: Double = 0
    private var spin: Double
    private var spinRate: Double = 0
    /// One slow turn about every 30 seconds, in every state.
    private static let turnRate = 2 * Double.pi / 30

    /// Each orb starts at its own point in the flow and its own face of the globe.
    init(seed: UInt64 = .random(in: 0...1000)) {
        phase = Double(seed % 1000) / 37
        spin = Double(seed % 628) / 100
    }

    func advance(to date: Date, state: OrbState, turnSpeed: Double = 1) -> OrbAppearance {
        let dt = min(max(date.timeIntervalSince(lastDate ?? date), 0), 0.1)
        lastDate = date
        clock += dt

        let target = Target(state)
        if lastState == nil {
            // Start where the state is, without easing in from defaults.
            settle(on: target)
            spinRate = Self.turnRate
        } else if let previous = lastState, !previous.isFinished, previous != .idle, state.isFinished {
            flashStart = date
        }
        lastState = state

        func ease(_ value: inout Double, to goal: Double, over seconds: Double) {
            value += (goal - value) * (1 - exp(-dt / seconds))
        }
        ease(&level, to: target.level, over: 0.6)
        ease(&energy, to: target.energy, over: 0.8)
        ease(&saturation, to: target.saturation, over: 0.6)
        // Speed changes ease slowly, so the flow gathers pace and coasts to a stop.
        ease(&rate, to: target.rate, over: 1.1)
        palette.blend(towards: ResolvedPalette(target.palette), amount: 1 - exp(-dt / 0.7))
        phase += dt * rate
        ease(&spinRate, to: Self.turnRate * turnSpeed, over: 1.5)
        spin += dt * spinRate

        var flash = 0.0
        if let start = flashStart {
            let t = date.timeIntervalSince(start) / 1.2
            if t < 1 { flash = sin(.pi * t) } else { flashStart = nil }
        }
        let breathing = state == .seeding ? 0.3 + 0.3 * sin(clock * 1.2) : 0
        ease(&bloom, to: max(breathing, flash), over: 0.3)

        return appearance
    }

    /// The orb holding still in a state, for Reduce Motion: no easing, no
    /// flow and no turning.
    func still(in state: OrbState) -> OrbAppearance {
        settle(on: Target(state))
        lastState = state
        lastDate = nil
        bloom = 0
        return appearance
    }

    private func settle(on target: Target) {
        level = target.level; energy = target.energy; saturation = target.saturation
        rate = target.rate; palette = ResolvedPalette(target.palette)
    }

    private var appearance: OrbAppearance {
        OrbAppearance(level: level, phase: phase, energy: energy, saturation: saturation,
                      palette: palette.palette, bloom: bloom, spin: spin)
    }

    /// Where each state wants the orb's parameters to settle.
    private struct Target {
        var level: Double
        var energy: Double
        var saturation: Double = 1
        var rate: Double
        var palette: OrbPalette = .active

        init(_ state: OrbState) {
            switch state {
            case .idle:
                level = 1; energy = 0.35; rate = 0.22
            case .downloading(let progress, let e):
                level = progress; energy = 0.5 + 0.5 * e; rate = 0.45 + 0.8 * e
            case .waiting(let progress):
                level = progress; energy = 0.3; rate = 0.2; palette = .waiting
            case .paused(let progress):
                level = progress; energy = 0.1; saturation = 0.2; rate = 0
            case .seeding:
                level = 1; energy = 0.45; rate = 0.3; palette = .finished
            case .finished:
                level = 1; energy = 0.4; rate = 0; palette = .finished
            case .failed(let progress):
                level = progress; energy = 0.25; rate = 0.06; palette = .failed
            }
            // Never quite empty, so there's always a little light to see.
            level = max(level, 0.05)
        }
    }
}

/// A palette as plain colour components, so two can be blended frame by frame.
private struct ResolvedPalette {
    var components: [Color.Resolved]

    init(_ palette: OrbPalette) {
        let environment = EnvironmentValues()
        components = ([palette.deep] + palette.ambient + palette.veils + [palette.glow]).map { $0.resolve(in: environment) }
    }

    mutating func blend(towards other: ResolvedPalette, amount: Double) {
        let t = Float(amount)
        for i in components.indices {
            let a = components[i], b = other.components[i]
            components[i] = Color.Resolved(red: a.red + (b.red - a.red) * t,
                                           green: a.green + (b.green - a.green) * t,
                                           blue: a.blue + (b.blue - a.blue) * t,
                                           opacity: a.opacity + (b.opacity - a.opacity) * t)
        }
    }

    var palette: OrbPalette {
        let c = components.map { Color($0) }
        return OrbPalette(deep: c[0], ambient: Array(c[1...3]), veils: Array(c[4...6]), glow: c[7])
    }
}
