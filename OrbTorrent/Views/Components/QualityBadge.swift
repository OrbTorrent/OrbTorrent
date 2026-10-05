import SwiftUI

/// A download's picture quality from its name, such as "4K HDR", beside
/// its tidy name. It never shortens: the name does first.
struct QualityBadge: View {
    let quality: String

    var body: some View {
        Text(quality)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 3.5)
            .padding(.vertical, 1)
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.tertiary, lineWidth: 1))
            .fixedSize()
    }
}
