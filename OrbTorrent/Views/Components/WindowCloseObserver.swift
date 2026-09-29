import AppKit
import SwiftUI

/// Calls `onClose` when the window holding this view stops being key.
///
/// The menu bar panel keeps its SwiftUI state while hidden and never gets a
/// second `onAppear`, so this is how it knows it was dismissed.
struct WindowCloseObserver: NSViewRepresentable {
    let onClose: () -> Void

    func makeNSView(context: Context) -> ObserverView {
        ObserverView(onClose: onClose)
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onClose = onClose
    }

    final class ObserverView: NSView {
        var onClose: () -> Void
        private var observation: NSObjectProtocol?

        init(onClose: @escaping () -> Void) {
            self.onClose = onClose
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observation { NotificationCenter.default.removeObserver(observation) }
            observation = nil
            guard let window else { return }
            observation = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: window, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.onClose() }
            }
        }
    }
}
