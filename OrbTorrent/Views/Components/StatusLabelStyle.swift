import SwiftUI

/// Sets a status's symbol close to its words, as OrbTorrent's other status
/// lines set their dot. A plain label leaves a wider gap, sized for lists.
struct StatusLabelStyle: LabelStyle {
    var spacing: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == StatusLabelStyle {
    static var status: StatusLabelStyle { StatusLabelStyle() }

    static func status(spacing: CGFloat) -> StatusLabelStyle { StatusLabelStyle(spacing: spacing) }
}
