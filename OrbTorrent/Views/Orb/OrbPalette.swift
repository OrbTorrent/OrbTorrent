import SwiftUI

/// The colours of the light inside the orb.
struct OrbPalette: Equatable {
    /// The darkest tone of the light.
    var deep: Color
    /// The broad colours the light is made of: three colours.
    var ambient: [Color]
    /// The brightest pools of light: three colours.
    var veils: [Color]
    /// The glow around the glass.
    var glow: Color

    /// Downloading, and the resting logo: blue.
    static let active = OrbPalette(
        deep: Color(red: 0.03, green: 0.04, blue: 0.16),
        ambient: [
            Color(red: 0.04, green: 0.18, blue: 0.68),
            Color(red: 0.15, green: 0.08, blue: 0.50),
            Color(red: 0.02, green: 0.40, blue: 0.80),
        ],
        veils: [
            Color(red: 0.42, green: 0.90, blue: 1.00),
            Color(red: 0.66, green: 0.46, blue: 1.00),
            Color(red: 0.30, green: 0.62, blue: 1.00),
        ],
        glow: Color(red: 0.22, green: 0.52, blue: 1.00)
    )

    /// Finished and seeding: green.
    static let finished = OrbPalette(
        deep: Color(red: 0.01, green: 0.09, blue: 0.10),
        ambient: [
            Color(red: 0.02, green: 0.40, blue: 0.36),
            Color(red: 0.03, green: 0.22, blue: 0.40),
            Color(red: 0.05, green: 0.48, blue: 0.30),
        ],
        veils: [
            Color(red: 0.46, green: 1.00, blue: 0.78),
            Color(red: 0.30, green: 0.88, blue: 1.00),
            Color(red: 0.66, green: 1.00, blue: 0.56),
        ],
        glow: Color(red: 0.20, green: 0.85, blue: 0.55)
    )

    /// Waiting for peers, checking or queued: amber.
    static let waiting = OrbPalette(
        deep: Color(red: 0.42, green: 0.14, blue: 0.03),
        ambient: [
            Color(red: 0.92, green: 0.46, blue: 0.06),
            Color(red: 0.80, green: 0.28, blue: 0.10),
            Color(red: 1.00, green: 0.64, blue: 0.14),
        ],
        veils: [
            Color(red: 1.00, green: 0.82, blue: 0.40),
            Color(red: 1.00, green: 0.62, blue: 0.26),
            Color(red: 1.00, green: 0.50, blue: 0.40),
        ],
        glow: Color(red: 1.00, green: 0.60, blue: 0.15)
    )

    /// Something went wrong: red.
    static let failed = OrbPalette(
        deep: Color(red: 0.13, green: 0.02, blue: 0.03),
        ambient: [
            Color(red: 0.56, green: 0.06, blue: 0.10),
            Color(red: 0.38, green: 0.04, blue: 0.20),
            Color(red: 0.64, green: 0.16, blue: 0.08),
        ],
        veils: [
            Color(red: 1.00, green: 0.52, blue: 0.46),
            Color(red: 1.00, green: 0.32, blue: 0.38),
            Color(red: 1.00, green: 0.62, blue: 0.42),
        ],
        glow: Color(red: 1.00, green: 0.25, blue: 0.25)
    )
}
