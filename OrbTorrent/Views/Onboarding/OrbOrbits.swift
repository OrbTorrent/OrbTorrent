import SwiftUI

/// Peers circling the orb on two tilted orbits, like moons round a planet.
/// It's drawn in two layers, so the far side of each orbit passes behind the
/// orb and the near side in front of it.
struct OrbOrbits: View {
    enum Side { case far, near }

    let side: Side
    /// The orb's diameter; the orbits are sized to it.
    let diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Orbit {
        /// Half the orbit's width and height, as fractions of the orb's diameter.
        let width: Double
        let height: Double
        let tilt: Angle
        let peers: Int
        /// Seconds for one trip round.
        let period: Double
        /// Where the first peer starts, as a fraction of a trip.
        let start: Double
    }

    private static let orbits = [
        Orbit(width: 0.74, height: 0.15, tilt: .degrees(-16), peers: 2, period: 12, start: 0.1),
        Orbit(width: 0.93, height: 0.24, tilt: .degrees(11), peers: 3, period: 19, start: 0.55),
    ]
    private static let line = Color(red: 0.42, green: 0.66, blue: 1.0)
    private static let peerColors = OrbPalette.active.veils

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                draw(in: &context, size: size, time: timeline.date.timeIntervalSinceReferenceDate)
            }
        }
        .frame(width: diameter * 2.1, height: diameter * 1.1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // Seen from a little above, the near side of an orbit is its lower half.
        let range = side == .near ? 0.0...Double.pi : Double.pi...(2 * Double.pi)
        for (index, orbit) in Self.orbits.enumerated() {
            let rx = orbit.width * diameter, ry = orbit.height * diameter
            let sinTilt = sin(orbit.tilt.radians), cosTilt = cos(orbit.tilt.radians)
            func point(_ angle: Double) -> CGPoint {
                let x = rx * cos(angle), y = ry * sin(angle)
                return CGPoint(x: center.x + x * cosTilt - y * sinTilt, y: center.y + x * sinTilt + y * cosTilt)
            }
            // 0 at the back of the orbit, 1 at the front.
            func nearness(_ angle: Double) -> Double { (sin(angle) + 1) / 2 }

            // The orbit: a faint line, brighter towards the front.
            let segments = 48
            let span = range.upperBound - range.lowerBound
            for k in 0..<segments {
                let from = range.lowerBound + span * Double(k) / Double(segments)
                let to = range.lowerBound + span * Double(k + 1) / Double(segments)
                var path = Path()
                path.move(to: point(from))
                path.addLine(to: point(to))
                context.stroke(path, with: .color(Self.line.opacity(0.1 + 0.22 * nearness((from + to) / 2))), lineWidth: 1)
            }

            // The peers on it, larger and brighter as they come round the front.
            for peer in 0..<orbit.peers {
                let turn = time / orbit.period + orbit.start + Double(peer) / Double(orbit.peers)
                let angle = (turn - turn.rounded(.down)) * 2 * .pi
                guard range.contains(angle) else { continue }
                let near = nearness(angle)
                let radius = diameter * (0.012 + 0.01 * near)
                let color = Self.peerColors[(index + peer) % Self.peerColors.count]
                let p = point(angle)
                var halo = context
                halo.addFilter(.blur(radius: radius * 1.6))
                halo.fill(Circle().path(in: CGRect(x: p.x - radius * 2.2, y: p.y - radius * 2.2,
                                                   width: radius * 4.4, height: radius * 4.4)),
                          with: .color(color.opacity(0.55 * (0.4 + 0.6 * near))))
                context.fill(Circle().path(in: CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(color.mix(with: .white, by: 0.35).opacity(0.5 + 0.5 * near)))
            }
        }
    }
}
