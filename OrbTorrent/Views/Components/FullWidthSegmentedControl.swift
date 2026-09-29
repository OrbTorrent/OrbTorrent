import AppKit
import SwiftUI

/// A segmented control whose segments share the full available width.
///
/// SwiftUI's segmented picker on macOS keeps its natural width and centres
/// itself, which leaves ragged gaps in a resizable inspector.
struct FullWidthSegmentedControl<Value: Hashable>: NSViewRepresentable {
    let options: [(title: String, value: Value)]
    @Binding var selection: Value

    func makeNSView(context: Context) -> NSSegmentedControl {
        let control = NSSegmentedControl(
            labels: options.map(\.title),
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.changed(_:))
        )
        control.segmentDistribution = .fillEqually
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return control
    }

    func updateNSView(_ control: NSSegmentedControl, context: Context) {
        context.coordinator.parent = self
        if let index = options.firstIndex(where: { $0.value == selection }), control.selectedSegment != index {
            control.selectedSegment = index
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSSegmentedControl, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? nsView.intrinsicContentSize.width, height: nsView.intrinsicContentSize.height)
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    @MainActor
    final class Coordinator: NSObject {
        var parent: FullWidthSegmentedControl

        init(parent: FullWidthSegmentedControl) {
            self.parent = parent
        }

        @objc func changed(_ sender: NSSegmentedControl) {
            guard parent.options.indices.contains(sender.selectedSegment) else { return }
            parent.selection = parent.options[sender.selectedSegment].value
        }
    }
}
