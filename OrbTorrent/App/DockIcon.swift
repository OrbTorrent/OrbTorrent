import AppKit

/// OrbTorrent lives in the menu bar; it shows a Dock icon (and its menus) only
/// while its window is open.
@MainActor
enum DockIcon {
    static func windowDidOpen(showDockIcon: Bool) {
        guard showDockIcon else { return }
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate()
    }

    static func windowDidClose() {
        // Give SwiftUI a moment to tear the window down before hiding the icon.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            let hasVisibleWindow = NSApp.windows.contains { window in
                window.isVisible && window.styleMask.contains(.titled) && !(window is NSPanel)
            }
            if !hasVisibleWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
