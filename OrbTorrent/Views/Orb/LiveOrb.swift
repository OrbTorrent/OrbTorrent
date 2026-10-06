import SwiftUI

/// The orb, animated live from a state: it turns slowly like a globe, fills
/// with progress, and changes colour and pace as the state changes.
///
/// With Reduce Motion it holds still and changes state without easing. It
/// also holds still while its window can't be seen.
struct LiveOrb: View {
    var state: OrbState
    /// How fast the globe turns, as a multiple of its usual pace; it
    /// gathers speed and coasts to the new pace.
    var turnSpeed: Double = 1
    @State private var motion = OrbMotion()
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                OrbView(appearance: motion.still(in: state))
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !isVisible)) { context in
                    OrbView(appearance: motion.advance(to: context.date, state: state, turnSpeed: turnSpeed))
                }
            }
        }
        .background(WindowVisibilityObserver { isVisible = $0 })
        .accessibilityHidden(true)
    }
}
