import SwiftUI

/// Library sections, the Extensions page pinned at the bottom, and a live
/// status card.
struct SidebarView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store = model.store
        let selection = Binding<SidebarFilter?>(
            get: { model.section == .library ? store.filter : nil },
            set: {
                guard let value = $0 else { return }
                store.filter = value
                model.section = .library
            }
        )

        List(selection: selection) {
            Section("Library") {
                ForEach(visibleFilters) { filter in
                    Label(filter.title, systemImage: filter.symbol)
                        .badge(store.count(for: filter))
                        .tag(filter)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 4) {
                ExtensionsSidebarItem()
                SidebarStatusCard()
                    .padding(.horizontal, 12)
            }
            .padding(.bottom, 12)
        }
        .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 300)
    }

    private var visibleFilters: [SidebarFilter] {
        SidebarFilter.allCases.filter { $0 != .errors || model.store.count(for: .errors) > 0 }
    }
}

/// The Extensions row, kept just above the status card. It's a list of its
/// own so it's selected the way the library's rows are.
private struct ExtensionsSidebarItem: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let selection = Binding<MainSection?>(
            get: { model.section == .extensions ? .extensions : nil },
            set: { if $0 == .extensions { model.section = .extensions } }
        )
        List(selection: selection) {
            HStack {
                Label("Extensions", systemImage: "puzzlepiece.extension")
                Spacer(minLength: 4)
                if !model.extensions.isOn {
                    Text("Off")
                        .foregroundStyle(.secondary)
                } else if needsAttention {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .help("An extension needs setting up, or couldn't load")
                }
            }
            .tag(MainSection.extensions)
        }
        .listStyle(.sidebar)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .frame(height: 44)
    }

    /// An extension that's on but can't run until it's set up, or one that
    /// couldn't load.
    private var needsAttention: Bool {
        let extensions = model.extensions
        let registry = extensions.registry
        return !registry.problems.isEmpty || registry.extensions.contains { item in
            registry.isEnabled(item) && (!item.isCompatible || !extensions.settings.missing(for: item).isEmpty)
        }
    }
}
