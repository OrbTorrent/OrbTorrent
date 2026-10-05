import SwiftUI

/// A download's name as OrbTorrent shows it, with its quality's badge. A
/// tidied name shows the full one when the pointer rests on it.
struct DownloadNameText: View {
    @Environment(AppModel.self) private var model
    let name: String

    var body: some View {
        let shown = model.store.shown(name)
        let label = HStack(spacing: 6) {
            Text(shown.text)
            if let quality = shown.quality {
                QualityBadge(quality: quality)
            }
        }
        if shown.text == name {
            label
        } else {
            label.help(name)
        }
    }
}
