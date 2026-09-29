import SwiftUI

/// The orb, animated live from a state: it turns slowly like a globe, fills
/// with progress, and changes colour and pace as the state changes.
///
/// With Reduce Motion it holds still and changes state without easing.
struct LiveOrb: View {
    var state: OrbState
    /// How fast the globe turns, as a multiple of its usual pace; it
    /// gathers speed and coasts to the new pace.
    var turnSpeed: Double = 1
    @State private var motion = OrbMotion()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                OrbView(appearance: motion.still(in: state))
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                    OrbView(appearance: motion.advance(to: context.date, state: state, turnSpeed: turnSpeed))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
