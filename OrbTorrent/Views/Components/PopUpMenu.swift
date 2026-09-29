import AppKit

/// Shows a native menu at the pointer from a button's action.
///
/// SwiftUI's `Menu` ignores custom button styles on macOS, so buttons that must
/// match the tiles around them open their menu through this instead.
@MainActor
enum PopUpMenu {
    struct Item {
        var title: String
        var systemImage: String?
        var keyEquivalent = ""
        var action: () -> Void

        /// A separator line.
        static var divider: Item { Item(title: "", action: {}) }
    }

    static func show(_ items: [Item]) {
        guard let event = NSApp.currentEvent, let view = event.window?.contentView else { return }
        let menu = NSMenu()
        for item in items {
            guard !item.title.isEmpty else {
                menu.addItem(.separator())
                continue
            }
            let menuItem = ClosureMenuItem(title: item.title, keyEquivalent: item.keyEquivalent, handler: item.action)
            if let symbol = item.systemImage {
                menuItem.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            }
            menu.addItem(menuItem)
        }
        let location = view.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: location, in: view)
    }
}

private final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, keyEquivalent: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func fire() {
        handler()
    }
}
