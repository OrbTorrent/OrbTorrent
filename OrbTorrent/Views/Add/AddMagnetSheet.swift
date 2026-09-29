import AppKit
import SwiftUI

/// Paste a magnet link or a link to a `.torrent` file.
struct AddMagnetSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var isValid: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if MagnetLink.first(in: trimmed) != nil { return true }
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                TorrentIcon(symbol: "link", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Magnet Link")
                        .font(.title3.weight(.semibold))
                    Text("Paste a magnet link or a link to a .torrent file.")
                        .foregroundStyle(.secondary)
                }
            }

            TextField("magnet:?xt=urn:btih:…", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .font(.callout.monospaced())
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit(add)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add", action: add)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)
                    .disabled(!isValid)
            }
            .controlSize(.large)
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            if let clipboard = NSPasteboard.general.string(forType: .string),
               MagnetLink.first(in: clipboard) != nil {
                text = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            isFocused = true
        }
    }

    private func add() {
        guard isValid else { return }
        dismiss()
        model.adder.add(text: text)
    }
}
