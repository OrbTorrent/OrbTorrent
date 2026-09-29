import SwiftUI

/// The status item: the orb, filling up as downloads progress.
///
/// It's only ever the icon, so the status item, and the panel anchored to
/// it, never change width or shift sideways.
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: MenuBarOrbIcon.image(for: model.orbState))
            .task {
                model.registerWindowOpener { openWindow(id: "main") }
            }
    }
}
