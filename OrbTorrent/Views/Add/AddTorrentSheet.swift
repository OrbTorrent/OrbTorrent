import SwiftUI

/// Review a torrent before it starts: the same confirmation as the menu bar
/// panel's, with the options the window offers.
struct AddTorrentSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Binding var pending: AddTorrentCoordinator.Pending

    var body: some View {
        AddConfirmation(
            pending: $pending,
            style: .window,
            onCancel: { cancelled in
                model.adder.cancel(cancelled)
                dismiss()
            },
            onDownload: { confirmed in
                dismiss()
                Task { await model.adder.confirm(confirmed) }
            }
        )
        .frame(width: 480)
    }
}

extension AddTorrentCoordinator {
    /// A torrent being asked about, as a binding that writes back to the
    /// coordinator, so the choices made survive the panels closing and
    /// reopening, and files its peers send show up.
    func binding(for asked: Pending) -> Binding<Pending> {
        Binding(
            get: { self.asked(asked.id) ?? asked },
            set: { changed in self.change(changed.id) { $0 = changed } }
        )
    }
}
