import AppKit
import SwiftUI

extension View {
    /// A menu for a right click or Control-click, for rows in a list. A list's
    /// own context menu draws a blue outline around the row, which in the menu
    /// bar panel is square and wider than the rounded rows; this one doesn't.
    func rightClickMenu<Menu: View>(@ViewBuilder _ menu: @escaping () -> Menu) -> some View {
        overlay { RightClickMenu(menu: menu) }
    }
}

private struct RightClickMenu<Menu: View>: NSViewRepresentable {
    let menu: () -> Menu

    func makeNSView(context: Context) -> MenuView {
        MenuView()
    }

    func updateNSView(_ view: MenuView, context: Context) {
        view.makeMenu = { NSHostingMenu(rootView: menu()) }
    }

    final class MenuView: NSView {
        var makeMenu: (() -> NSMenu)?

        /// Only clicks that open the menu land here; everything else goes
        /// through to the row underneath.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent, Self.opensMenu(event) else { return nil }
            return super.hitTest(point)
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            makeMenu?()
        }

        override func mouseDown(with event: NSEvent) {
            if let menu = menu(for: event) {
                NSMenu.popUpContextMenu(menu, with: event, for: self)
            }
        }

        private static func opensMenu(_ event: NSEvent) -> Bool {
            switch event.type {
            case .rightMouseDown, .rightMouseUp: true
            case .leftMouseDown, .leftMouseUp: event.modifierFlags.contains(.control)
            default: false
            }
        }
    }
}
