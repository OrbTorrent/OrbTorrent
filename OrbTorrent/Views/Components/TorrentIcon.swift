import SwiftUI

/// A tinted rounded-square icon for a torrent or file.
struct TorrentIcon: View {
    let symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 36
    /// Spins in place of the symbol, while what the torrent holds isn't known yet.
    var isLoading = false
    @Environment(\.backgroundProminence) private var prominence
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let color = prominence == .increased ? Color.white : tint
        // In dark mode the symbol is a little lighter than its tile, so a blue
        // folder doesn't sink into a navy square on the panel's glass.
        let symbolColor = prominence != .increased && colorScheme == .dark ? tint.mix(with: .white, by: 0.2) : color
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(size >= 32 ? .small : .mini)
            } else {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.44, weight: .semibold))
                    .foregroundStyle(symbolColor)
            }
        }
        .frame(width: size, height: size)
        .background(color.opacity(0.2), in: .rect(cornerRadius: size * 0.28))
        .overlay(RoundedRectangle(cornerRadius: size * 0.28).strokeBorder(color.opacity(0.3), lineWidth: 1))
        .accessibilityHidden(true)
    }
}
