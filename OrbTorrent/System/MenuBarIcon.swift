import AppKit
import ApplicationServices

/// Where OrbTorrent's menu bar icon and panel are on screen.
///
/// SwiftUI's `MenuBarExtra` exposes neither. AppKit's windows for the icon
/// can't be trusted either: each display's menu bar has its own copy, and the
/// copies on displays not in use are often out of date. Accessibility reports
/// where the icon actually is, in the menu bar of the display in use, and an
/// app may always ask it about itself.
@MainActor
enum MenuBarIcon {
    /// The menu bar panel's window, once it has been shown.
    static weak var panel: NSWindow?

    /// Closes the menu bar panel, as clicking outside it does. SwiftUI has no
    /// way to, and it stays open when the panel opens another of the app's windows.
    static func closePanel() {
        guard let panel, panel.isVisible else { return }
        if panel.isReleasedWhenClosed {
            panel.orderOut(nil)
        } else {
            panel.close()
        }
    }

    /// The icon's frame on screen, waiting briefly for it while OrbTorrent launches.
    static func frame() async -> NSRect? {
        for _ in 0..<30 {
            if let frame = accessibilityFrame() { return frame }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return nil
    }

    private static func accessibilityFrame() -> NSRect? {
        let app = AXUIElementCreateApplication(getpid())
        guard let bar = element(value(of: "AXExtrasMenuBar", in: app)),
              let items = value(of: kAXChildrenAttribute, in: bar) as? [AXUIElement],
              let item = items.first,
              let top = NSScreen.screens.first?.frame.maxY
        else { return nil }
        var origin = CGPoint.zero, extent = CGSize.zero
        guard let position = axValue(value(of: kAXPositionAttribute, in: item)),
              let size = axValue(value(of: kAXSizeAttribute, in: item)),
              AXValueGetValue(position, .cgPoint, &origin),
              AXValueGetValue(size, .cgSize, &extent),
              extent.width > 0
        else { return nil }
        // Accessibility measures down from the top of the main display.
        return NSRect(x: origin.x, y: top - origin.y - extent.height, width: extent.width, height: extent.height)
    }

    private static func value(of attribute: String, in element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
    }

    private static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func axValue(_ value: CFTypeRef?) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }
}
