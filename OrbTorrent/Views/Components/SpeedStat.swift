import SwiftUI

/// A transfer rate with a direction arrow, such as "↓ 9.8 MB/s".
struct SpeedStat: View {
    enum Direction {
        case down, up

        var symbol: String { self == .down ? "arrow.down" : "arrow.up" }
        var label: String { self == .down ? "Download" : "Upload" }
        var tint: Color { self == .down ? .accentColor : .green }
    }

    let direction: Direction
    let bytesPerSecond: Int64

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: direction.symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(direction.tint)
            Text(Format.speed(bytesPerSecond))
                .font(.callout.weight(.medium))
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .animation(.snappy, value: bytesPerSecond)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(direction.label) speed")
    }
}
