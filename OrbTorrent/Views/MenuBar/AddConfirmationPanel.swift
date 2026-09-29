import AppKit
import SwiftUI

/// The menu bar panel, dropped down by OrbTorrent itself to ask about torrents
/// opened from other apps. SwiftUI's `MenuBarExtra` can't be opened from code.
///
/// While asking it stays until the person adds the torrent or cancels, even
/// when they click elsewhere, on the display in use when the torrent arrived.
/// Once they add it, it shows their downloads and closes like the menu bar
/// panel does. That panel asks the same question while it's open, so this one
/// steps aside for it.
@MainActor
final class AddConfirmationPanel {
    /// Transparent room around the glass inside the window. The glass draws
    /// its own shadow outside its shape; a window sized to the glass would cut
    /// that shadow off at its square edges, leaving a dark rectangle.
    fileprivate static let shadowRoom: CGFloat = 24

    private let model: AppModel
    private let panel: NSPanel
    private var observers: [NSObjectProtocol] = []
    /// Showing the downloads after an add, rather than asking.
    private var showsDownloads = false

    init(model: AppModel) {
        self.model = model
        panel = FloatingPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // The glass has its own shadow; the window's would follow its square edges.
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: DropDownContent(
            model: model,
            onResize: { [weak self] size in self?.fit(size) },
            onAnswered: { [weak self] in self?.answered() }
        ))
        observeWindows()
    }

    /// Asks about the torrents waiting, unless the menu bar panel is asking
    /// already. It takes the keyboard when it first appears, so Return adds
    /// and Escape cancels.
    func show(focus: Bool = true) async {
        guard !model.adder.menuBarQueue.isEmpty, MenuBarIcon.panel?.isVisible != true else { return }
        showsDownloads = false
        let size = panel.contentView?.fittingSize ?? panel.frame.size
        panel.setFrame(await frame(for: size), display: true)
        panel.orderFrontRegardless()
        if focus { panel.makeKey() }
    }

    /// Goes on to show the downloads once the torrent asked about is added.
    func showDownloads() {
        guard panel.isVisible else { return }
        showsDownloads = true
        panel.makeKey()
    }

    private func answered() {
        // Cancelled rather than added: nothing more to show.
        if !showsDownloads { hide() }
    }

    private func hide() {
        showsDownloads = false
        panel.orderOut(nil)
    }

    /// Where the menu bar panel opens: 1 pt right of the icon's left edge and
    /// 6.5 pt below it, in the menu bar of the display in use. The window is
    /// larger than the glass by the room left for its shadow.
    private func frame(for size: CGSize) async -> NSRect {
        let room = Self.shadowRoom
        let glass = CGSize(width: size.width - room * 2, height: size.height - room * 2)
        let icon = await MenuBarIcon.frame()
        let screen = icon.flatMap { icon in NSScreen.screens.first { $0.frame.intersects(icon) } }
            ?? NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        let bounds = screen?.frame ?? .zero
        let top = icon.map { $0.minY - 6.5 } ?? bounds.maxY - 34
        let left = icon.map { $0.minX + 1 } ?? bounds.maxX - glass.width - 8
        let x = min(max(left, bounds.minX + 8), bounds.maxX - glass.width - 8)
        return NSRect(x: x - room, y: top - glass.height - room, width: size.width, height: size.height)
    }

    /// Grows or shrinks with its content, keeping its top edge in place.
    private func fit(_ size: CGSize) {
        guard size.width > 0, size.height > 0, size != panel.frame.size else { return }
        var frame = panel.frame
        frame.origin.y = frame.maxY - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
    }

    private func observeWindows() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] note in
            let window = (note.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                guard let self, window != nil, window == MenuBarIcon.panel.map(ObjectIdentifier.init) else { return }
                self.hide()
            }
        })
        observers.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: nil, queue: .main) { [weak self] note in
            let window = (note.object as AnyObject?).map(ObjectIdentifier.init)
            MainActor.assumeIsolated {
                guard let self, let window else { return }
                if window == ObjectIdentifier(self.panel) {
                    // Showing the downloads, it closes like the menu bar panel.
                    if self.showsDownloads && self.model.adder.menuBarQueue.isEmpty { self.hide() }
                } else if window == MenuBarIcon.panel.map(ObjectIdentifier.init) {
                    // Once the menu bar panel has closed, go back to asking, without
                    // taking the keyboard from wherever the person clicked.
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        await self.show(focus: false)
                    }
                }
            }
        })
    }
}

/// A borderless panel that can still take the keyboard.
private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private struct DropDownContent: View {
    let model: AppModel
    let onResize: (CGSize) -> Void
    let onAnswered: () -> Void

    var body: some View {
        MenuBarPanel(isMenuBarExtra: false)
            .fixedSize(horizontal: false, vertical: true)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .padding(AddConfirmationPanel.shadowRoom)
            .environment(model)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onResize($0) }
            .onChange(of: model.adder.menuBarQueue.isEmpty) { _, isEmpty in
                if isEmpty { onAnswered() }
            }
    }
}
