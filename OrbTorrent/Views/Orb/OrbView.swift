import SwiftUI

/// The orb at one moment: coloured light that turns like a globe, filled to
/// a level, held inside the system's Liquid Glass.
///
/// `LiveOrb` animates it; this view only draws what it's given.
struct OrbView: View {
    var appearance: OrbAppearance

    private var a: OrbAppearance { appearance }

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width, geo.size.height)
            orb(d)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    /// The glass as the vessel, with the light sitting crisply inside it.
    private func orb(_ d: CGFloat) -> some View {
        let inset = d * 0.045
        let inner = d - 2 * inset
        return ZStack {
            // A little colour in the glass, so an empty orb still reads as one.
            Circle()
                .fill(RadialGradient(colors: [a.palette.veils[0].opacity(0.24), a.palette.ambient[0].opacity(0.10)],
                                     center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: inner * 0.62))
                .saturation(a.saturation)
                .padding(inset)
            ZStack {
                globe(d)
                volume(d, inset: inset, inner: inner)
            }
            .mask(LiquidShape(level: a.level, phase: a.phase, amplitude: waveAmplitude))
            .overlay { surfaceLine(d) }
            .saturation(a.saturation)
            .clipShape(Circle().inset(by: inset))
            // A highlight across the light, so it sits under the same glass.
            Crescent(thickness: 0.028, angle: .degrees(-120))
                .fill(LinearGradient(stops: [
                    .init(color: .white.opacity(0.6), location: 0),
                    .init(color: .white.opacity(0), location: 0.4),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(inset)
                .blur(radius: d * 0.003)
        }
        .frame(width: d, height: d)
        .glassEffect(.clear, in: Circle())
        .background(
            Circle()
                .fill(a.palette.glow)
                .blur(radius: d * 0.12)
                .opacity(0.12 + 0.25 * a.energy * a.level + 0.3 * a.bloom)
                .scaleEffect(0.86 + 0.08 * a.bloom)
        )
    }

    /// Shading that makes the light read as a sphere.
    private func volume(_ d: CGFloat, inset: CGFloat, inner: CGFloat) -> some View {
        ZStack {
            // The light darkens towards its edge…
            Circle()
                .fill(RadialGradient(stops: [
                    .init(color: .clear, location: 0.55),
                    .init(color: .black.opacity(0.28), location: 1),
                ], center: UnitPoint(x: 0.45, y: 0.4), startRadius: 0, endRadius: inner * 0.56))
                .padding(inset)
            // …is lit from the upper left, like the sunlit side of a planet;
            // the light stays put while the surface turns beneath it…
            Circle()
                .fill(RadialGradient(colors: [a.palette.veils[0].opacity(0.55), a.palette.veils[0].opacity(0)],
                                     center: UnitPoint(x: 0.32, y: 0.28), startRadius: 0, endRadius: inner * 0.5))
                .padding(inset)
                .blendMode(.plusLighter)
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.22), .white.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: inner * 0.3))
                .frame(width: inner * 0.62, height: inner * 0.4)
                .offset(x: -inner * 0.12, y: -inner * 0.26)
                .blendMode(.plusLighter)
            // …and brightens along the bottom, where light passes through.
            Crescent(thickness: 0.05, angle: .degrees(90))
                .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .bottom, endPoint: .center))
                .padding(inset)
                .blur(radius: d * 0.01)
                .blendMode(.plusLighter)
        }
    }

    /// The surface moves more when the orb is busier, and flattens out as
    /// the orb nears empty or full.
    private var waveAmplitude: Double {
        0.022 * (0.5 + 0.5 * a.energy) * min(1, sin(.pi * a.level) * 2.5)
    }

    @ViewBuilder
    private func surfaceLine(_ d: CGFloat) -> some View {
        if a.level > 0.005 && a.level < 0.995 {
            LiquidShape(level: a.level, phase: a.phase, amplitude: waveAmplitude, surfaceOnly: true)
                .stroke(.white.opacity(0.55), lineWidth: max(0.5, d * 0.007))
                .blur(radius: d * 0.002)
        }
    }

    // MARK: Globe

    /// Pools of colour on the surface of a sphere that slowly turns, like
    /// Earth: they travel fastest across the middle and bunch up as they
    /// curve away at the edges and towards the poles.
    ///
    /// A fixed grid of points covers the orb; each frame, every point takes
    /// the colour of whatever part of the turning globe sits under it, and
    /// the mesh gradient blends smoothly between them.
    private func globe(_ d: CGFloat) -> some View {
        let n = d > 60 ? 9 : 7
        let t = a.phase
        let p = a.palette
        let environment = EnvironmentValues()
        let base = p.ambient[0].resolve(in: environment)
        // Where each pool sits on the globe (longitude, latitude), how wide
        // it is, and its colour. They drift a little, so the surface flows.
        let pools: [(longitude: Double, latitude: Double, width: Double, color: Color.Resolved)] = [
            (0.0, 0.5, 0.11, p.veils[0]), (0.8, -0.3, 0.14, p.veils[1]), (1.6, 0.25, 0.15, p.deep),
            (2.4, -0.45, 0.11, p.veils[2]), (3.1, 0.4, 0.14, p.ambient[1]), (3.9, -0.1, 0.1, p.veils[0]),
            (4.7, 0.55, 0.14, p.veils[1]), (5.5, -0.35, 0.15, p.ambient[2]),
        ].enumerated().map { k, pool in
            let k = Double(k)
            return (pool.0 + 0.25 * sin(t * 0.31 + k * 1.7), pool.1 + 0.18 * sin(t * 0.27 + k * 2.3),
                    pool.2, pool.3.resolve(in: environment))
        }
        let centers = pools.map { pool in
            SIMD3(cos(pool.latitude) * sin(pool.longitude), sin(pool.latitude), cos(pool.latitude) * cos(pool.longitude))
        }

        var points: [SIMD2<Float>] = []
        var colors: [Color] = []
        points.reserveCapacity(n * n)
        colors.reserveCapacity(n * n)
        for row in 0..<n {
            for column in 0..<n {
                let x = Double(column) / Double(n - 1), y = Double(row) / Double(n - 1)
                points.append([Float(x), Float(y)])
                // The point on the globe under this spot; spots outside the
                // circle take the colour at its rim.
                var dx = (x - 0.5) * 2, dy = (0.5 - y) * 2
                let length = (dx * dx + dy * dy).squareRoot()
                if length > 1 { dx /= length; dy /= length }
                let cosLatitude = max(0, 1 - dy * dy).squareRoot()
                let sinLongitude = cosLatitude > 1e-6 ? min(1, max(-1, dx / cosLatitude)) : 0
                let longitude = asin(sinLongitude) - a.spin
                let point = SIMD3(cosLatitude * sin(longitude), dy, cosLatitude * cos(longitude))

                var r = Double(base.red) * 0.12, g = Double(base.green) * 0.12, b = Double(base.blue) * 0.12
                var total = 0.12
                for (pool, center) in zip(pools, centers) {
                    let weight = exp(((point * center).sum() - 1) / pool.width)
                    r += Double(pool.color.red) * weight
                    g += Double(pool.color.green) * weight
                    b += Double(pool.color.blue) * weight
                    total += weight
                }
                colors.append(Color(.sRGB, red: r / total, green: g / total, blue: b / total))
            }
        }
        return MeshGradient(width: n, height: n, points: points, colors: colors, smoothsColors: true)
            .saturation(1.2)
            .frame(width: d, height: d)
    }
}
