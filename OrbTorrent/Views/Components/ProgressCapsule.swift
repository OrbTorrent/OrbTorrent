import SwiftUI

/// A slim, rounded progress bar.
struct ProgressCapsule: View {
    let value: Double
    var tint: Color = .accentColor
    var height: CGFloat = 6
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let isProminent = prominence == .increased
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isProminent ? AnyShapeStyle(.white.opacity(0.25)) : AnyShapeStyle(.quaternary))
                Capsule()
                    .fill(isProminent ? AnyShapeStyle(.white) : AnyShapeStyle(tint.gradient))
                    .frame(width: max(proxy.size.width * min(max(value, 0), 1), value > 0 ? height : 0))
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.4), value: value)
        .accessibilityElement()
        .accessibilityLabel("Progress")
        .accessibilityValue(Format.percent(value))
    }
}
