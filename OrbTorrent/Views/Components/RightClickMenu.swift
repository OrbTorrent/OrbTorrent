import AppKit
import SwiftUI

extension View {
    /// A menu for a right click or Control-click, for rows in a list. A list's
    /// own context menu draws a blue outline around the row, which in the menu
    /// bar panel is square and wider than the rounded rows; this one doesn't.
    ///
    /// While a menu is open, rows get no hover changes, so right-clicking
    /// another row would leave the highlight on the first. `onOpenChange` says
    /// when the menu opens, and when it closes whether the pointer is still
    /// over the row, for the row to show as hovered instead.
    func rightClickMenu<Menu: View>(
        @ViewBuilder _ menu: @escaping () -> Menu,
        onOpenChange: @escaping (_ isOpen: Bool, _ pointerInside: Bool) -> Void = { _, _ in }
    ) -> some View {
        overlay { RightClickMenu(menu: menu, onOpenChange: onOpenChange) }
    }
}

private struct RightClickMenu<Menu: View>: NSViewRepresentable {
    let menu: () -> Menu
    let onOpenChange: (Bool, Bool) -> Void

    func makeNSView(context: Context) -> MenuView {
        MenuView()
    }

    func updateNSView(_ view: MenuView, context: Context) {
        view.makeMenu = { NSHostingMenu(rootView: menu()) }
        view.onOpenChange = onOpenChange
    }

    final class MenuView: NSView {
        var makeMenu: (() -> NSMenu)?
        var onOpenChange: ((Bool, Bool) -> Void)?

        /// Only clicks that open the menu land here; everything else goes
        /// through to the row underneath.
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard let event = NSApp.currentEvent, Self.opensMenu(event) else { return nil }
            return super.hitTest(point)
        }

        override func rightMouseDown(with event: NSEvent) {
            showMenu(for: event)
        }

        /// Only Control-clicks land here.
        override func mouseDown(with event: NSEvent) {
            showMenu(for: event)
        }

        private func showMenu(for event: NSEvent) {
            guard let menu = makeMenu?() else { return }
            onOpenChange?(true, true)
            // Returns once the menu closes.
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            onOpenChange?(false, isPointerInside)
        }

        private var isPointerInside: Bool {
            guard let window else { return false }
            return bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
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
