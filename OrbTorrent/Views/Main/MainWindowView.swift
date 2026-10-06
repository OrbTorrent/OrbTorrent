import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The library window.
struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = model
        @Bindable var store = model.store
        @Bindable var adder = model.adder
        @Bindable var extensions = model.extensions
        @Bindable var updates = model.updates
        let showsLibrary = model.section == .library

        NavigationSplitView {
            SidebarView()
        } detail: {
            switch model.section {
            case .library:
                TorrentListView()
                    .overlay { EngineStatusOverlay() }
                    .inspector(isPresented: $model.isInspectorPresented) {
                        InspectorContainer()
                    }
            case .extensions:
                ExtensionsView()
            }
        }
        .toolbar {
            if showsLibrary { toolbar } else { extensionsToolbar }
        }
        .searchable(text: showsLibrary ? $store.searchText : $model.extensionSearch, placement: .toolbar,
                    prompt: searchPrompt)
        .overlay(alignment: .top) {
            VStack(spacing: 0) {
                UpdateBanner()
                DefaultAppBanner()
            }
            .animation(.smooth, value: model.updates.waiting)
            .animation(.smooth, value: model.updates.ready)
        }
        .overlay(alignment: .bottom) { toast }
        .dropDestination(for: URL.self) { urls, _ in
            model.adder.open(urls)
            return true
        }
        .onPasteCommand(of: [.url, .plainText]) { providers in
            handlePaste(providers)
        }
        .sheet(item: $adder.pending) { pending in
            AddTorrentSheet(pending: adder.binding(for: pending))
        }
        .sheet(isPresented: $adder.isMagnetSheetPresented) {
            AddMagnetSheet()
        }
        .sheet(isPresented: $model.isWelcomePresented) {
            WelcomeView()
        }
        .sheet(isPresented: $updates.isWhatsNewPresented, onDismiss: { model.updates.didDismissWhatsNew() }) {
            WhatsNewView(releases: model.updates.whatsNew)
        }
        .confirmationDialog(removalTitle, isPresented: $model.isRemovalConfirmationPresented, titleVisibility: .visible) {
            Button("Remove from OrbTorrent") { model.confirmRemoval(deletingFiles: false) }
            switch model.settings.deleteBehavior {
            case .moveToTrash:
                Button("Remove and Move Files to Trash", role: .destructive) { model.confirmRemoval(deletingFiles: true) }
            case .deletePermanently:
                Button("Remove and Delete Files Permanently", role: .destructive) { model.confirmRemoval(deletingFiles: true) }
            }
            Button("Cancel", role: .cancel) { model.removalCandidates = [] }
        } message: {
            switch model.settings.deleteBehavior {
            case .moveToTrash:
                Text("“Remove from OrbTorrent” keeps the downloaded files. Files moved to the Trash can be put back from there.")
            case .deletePermanently:
                Text("“Remove from OrbTorrent” keeps the downloaded files. Deleted files are erased from your Mac and can't be put back.")
            }
        }
        .alert("Something Went Wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.actionError ?? adder.errorMessage ?? "")
        }
        .sheet(item: $model.importSource) { source in
            ImportSheet(source: source)
        }
        .sheet(item: $extensions.installRequest) { candidate in
            ExtensionInstallSheet(candidate: candidate) { install in
                model.finishInstall(candidate, install: install)
            }
        }
        .alert("The Extension Couldn't Be Installed", isPresented: Binding(get: { extensions.installError != nil },
                                                                            set: { if !$0 { extensions.installError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(extensions.installError ?? "")
        }
        .onAppear {
            model.registerWindowOpener { openWindow(id: "main") }
            DockIcon.windowDidOpen(showDockIcon: model.settings.showDockIcon)
            model.defaultApp.refresh()
        }
        .onDisappear {
            DockIcon.windowDidClose()
        }
        // The default app can change elsewhere while the window is open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.defaultApp.refresh()
        }
        // Height only: the columns' own minimums set the narrowest width. A
        // minimum width here lets the split view outgrow the window while the
        // inspector slides in, shoving the sidebar off the left edge.
        .frame(minHeight: 460)
        .animatesOnlyWhileVisible()
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        let selected = model.store.selectedTorrents
        let anyRunning = selected.contains { !$0.state.isStopped }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Open Torrent File…", systemImage: "doc.badge.plus") { model.adder.presentOpenPanel() }
                Button("Add Magnet Link…", systemImage: "link.badge.plus") { model.adder.presentMagnetSheet() }
            } label: {
                Label("Add", systemImage: "plus")
            } primaryAction: {
                model.adder.presentMagnetSheet()
            }
            .help("Add a magnet link (hold to open a .torrent file)")
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .primaryAction) {
            Button(anyRunning ? "Pause" : "Resume", systemImage: anyRunning ? "pause.fill" : "play.fill") {
                Task { await model.store.togglePause(selected) }
            }
            .disabled(selected.isEmpty)
            .help(anyRunning ? "Pause" : "Resume")

            Button("Remove", systemImage: "trash") {
                model.requestRemoval(of: selected)
            }
            .disabled(selected.isEmpty)
            .help("Remove…")
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("Sort By", selection: Bindable(model.store).sort) {
                    ForEach(TorrentSort.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
                Picker("Group By", selection: Bindable(model.settings).listGrouping) {
                    ForEach(TorrentGrouping.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.inline)
            } label: {
                Label("Sort and Group", systemImage: "arrow.up.arrow.down")
            }
            .help("Sort and group downloads")

            Button("Inspector", systemImage: "sidebar.trailing") {
                model.isInspectorPresented.toggle()
            }
            .help(model.isInspectorPresented ? "Hide Inspector" : "Show Inspector")
        }
    }

    private var searchPrompt: String {
        switch model.section {
        case .library: "Search Downloads"
        case .extensions: model.extensionsTab == .activity && model.extensionPath.isEmpty ? "Search Checks" : "Search Extensions"
        }
    }

    @ToolbarContentBuilder
    private var extensionsToolbar: some ToolbarContent {
        if model.extensionPath.isEmpty && model.extensions.isOn {
            ToolbarItem(placement: .principal) {
                Picker("Show", selection: Bindable(model).extensionsTab) {
                    ForEach(ExtensionsTab.allCases) { tab in
                        Text(title(of: tab)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
    }

    /// Activity counts the downloads a check is holding.
    private func title(of tab: ExtensionsTab) -> String {
        let held = model.extensions.checks.gated.values.filter { $0 == .held }.count
        return tab == .activity && held > 0 ? "\(tab.title) (\(held))" : tab.title
    }

    @ViewBuilder
    private var toast: some View {
        if let notice = model.adder.notice {
            ToastView(message: notice)
                .padding(.bottom, 24)
                .task(id: notice) {
                    try? await Task.sleep(for: .seconds(2.5))
                    withAnimation { model.adder.notice = nil }
                }
        }
    }

    private var removalTitle: String {
        let items = model.removalCandidates
        return items.count == 1
            ? "Remove “\(model.store.shownName(items[0].name))”?"
            : "Remove \(items.count) Downloads?"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.store.actionError != nil || model.adder.errorMessage != nil },
            set: { if !$0 { model.store.actionError = nil; model.adder.errorMessage = nil } }
        )
    }

    private func handlePaste(_ providers: [NSItemProvider]) {
        if let text = NSPasteboard.general.string(forType: .string), model.adder.add(text: text) {
            return
        }
        if let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self]) as? [URL] {
            model.adder.open(urls)
        }
    }
}
