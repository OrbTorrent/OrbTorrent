import AppKit
import SwiftUI

/// Calls `onChange` with whether the window holding this view can be seen:
/// it's open, on the current Space and not covered, and the display is on.
///
/// Animations pause when it can't. The menu bar panel's views stay alive while
/// it's closed, even before it first opens, and would otherwise draw every frame.
struct WindowVisibilityObserver: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> ObserverView {
        ObserverView(onChange: onChange)
    }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onChange = onChange
    }

    final class ObserverView: NSView {
        var onChange: (Bool) -> Void
        private var observation: NSObjectProtocol?

        init(onChange: @escaping (Bool) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observation { NotificationCenter.default.removeObserver(observation) }
            observation = nil
            if let window {
                observation = NotificationCenter.default.addObserver(
                    forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main
                ) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                }
            }
            // After SwiftUI's update, as reporting changes the view's state.
            DispatchQueue.main.async { [weak self] in self?.report() }
        }

        private func report() {
            onChange(window?.occlusionState.contains(.visible) ?? false)
        }
    }
}

extension View {
    /// Turns off animations while the window holding this view can't be
    /// seen, so progress bars and the like change without drawing frames.
    func animatesOnlyWhileVisible() -> some View {
        modifier(AnimatesOnlyWhileVisible())
    }
}

private struct AnimatesOnlyWhileVisible: ViewModifier {
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .transaction { transaction in
                if !isVisible {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
            .background(WindowVisibilityObserver { isVisible = $0 })
    }
}
