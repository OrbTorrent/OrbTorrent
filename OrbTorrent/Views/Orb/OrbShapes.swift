import SwiftUI

/// The light inside the orb, filled to a level with a gently moving surface.
struct LiquidShape: Shape {
    var level: Double
    var phase: Double
    /// The surface's wave height, as a fraction of the height.
    var amplitude: Double
    /// Just the surface line, for drawing a stroke along it.
    var surfaceOnly = false

    func path(in rect: CGRect) -> Path {
        let h = rect.height
        let top = rect.maxY - level * (h + 2 * amplitude * h) + amplitude * h
        let steps = 60
        var path = Path()
        for i in 0...steps {
            let u = Double(i) / Double(steps)
            let x = rect.minX + rect.width * u
            let wave = sin(u * .pi * 1.9 + phase * 1.4) * 0.65 + sin(u * .pi * 3.7 - phase * 0.95) * 0.35
            let point = CGPoint(x: x, y: top + amplitude * h * wave)
            if i == 0 {
                if surfaceOnly {
                    path.move(to: point)
                } else {
                    path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                    path.addLine(to: point)
                }
            } else {
                path.addLine(to: point)
            }
        }
        if !surfaceOnly {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// A crescent hugging the inside of a circle: the circle minus a copy of
/// itself shifted towards the centre.
struct Crescent: Shape {
    /// How far the inner circle is shifted, as a fraction of the diameter.
    var thickness: Double
    /// Where the crescent is thickest, measured like SwiftUI rotations (0° = right, 90° = down).
    var angle: Angle

    func path(in rect: CGRect) -> Path {
        let d = min(rect.width, rect.height)
        let shift = d * thickness
        let inner = rect.offsetBy(dx: -cos(angle.radians) * shift, dy: -sin(angle.radians) * shift)
            .insetBy(dx: d * 0.004, dy: d * 0.004)
        return Path(ellipseIn: rect).subtracting(Path(ellipseIn: inner))
    }
}
