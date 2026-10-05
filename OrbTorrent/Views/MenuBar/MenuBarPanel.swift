import AppKit
import SwiftUI

/// The menu bar panel's grid. Everything starts at the panel's own margin.
/// Boxes that hold rows (the checks card, a download's highlight, the held
/// strip) pad their contents and reach out by the same amount, so what's
/// inside them lines up with everything outside.
enum PanelGrid {
    static let boxPadding: CGFloat = 10
    /// Boxes that stay within the margins (the checks card, a download's file
    /// rows) pad their contents by this much.
    static let cardPadding: CGFloat = 12
    /// Text after a large icon (the orb, a download's icon) starts here.
    static let largeText: CGFloat = 32 + 10
    /// Checkboxes, the folder, the disk and the check ring share one size,
    /// so the text after them starts in one column.
    static let glyph: CGFloat = 16
    static let glyphGap: CGFloat = 8
    static let smallText: CGFloat = glyph + glyphGap
}

extension View {
    /// Reaches out by a box's padding, so the box's contents line up with
    /// the rows outside it.
    func reachesOut(by padding: CGFloat = PanelGrid.boxPadding) -> some View {
        self.padding(.horizontal, -padding)
    }
}

/// The panel shown from the menu bar icon.
///
/// It lists every download, busiest first, in a list that scrolls once
/// there are more than about six; clicking one shows its files right in the
/// panel, where they can be opened, skipped or prioritised.
struct MenuBarPanel: View {
    /// False when shown in the panel OrbTorrent drops down itself, rather
    /// than in SwiftUI's `MenuBarExtra`.
    var isMenuBarExtra = true
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @State private var clipboardMagnet: MagnetLink?
    /// The download whose files are shown, if any.
    @State private var focusedHash: String?
    /// The download whose row is asking to delete it, if any.
    @State private var deletingHash: String?
    /// The ends of the list with more downloads past them, which fade out.
    @State private var listEdges: Edge.Set = []
    @State private var listPosition = ScrollPosition(edge: .top)
    /// About six and a half rows, so the panel stays a steady size however
    /// many downloads there are, and the half row says there are more.
    private let maxListHeight: CGFloat = 375

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MenuBarHeader()
            Divider()

            if let asking = model.adder.menuBarQueue.first {
                AddConfirmation(
                    pending: model.adder.binding(for: asking),
                    waiting: model.adder.menuBarQueue.count,
                    onCancel: { model.adder.decline($0) },
                    onDownload: { confirmed in Task { await model.adder.confirm(confirmed) } },
                    // Choosing may have closed the menu bar panel; keep asking.
                    afterChoosingFolder: { model.adder.showMenuBarConfirmation?() }
                )
                .id(asking.id)
            } else if let focusedHash, let torrent = model.store.torrent(focusedHash) {
                MenuBarTorrentDetail(torrent: torrent, store: model.store) {
                    self.focusedHash = nil
                }
                .id(torrent.hash)
            } else {
                updateStrip
                content
                clipboardButton
                footer
            }
        }
        .padding(14)
        .frame(width: 380)
        .background(WindowReader { if isMenuBarExtra { MenuBarIcon.panel = $0 } })
        .background(WindowCloseObserver {
            // Reopen on the top of the list, with a fresh look at the clipboard.
            focusedHash = nil
            deletingHash = nil
            listPosition.scrollTo(edge: .top)
            clipboardMagnet = model.adder.clipboardMagnet()
        })
        .onAppear {
            clipboardMagnet = model.adder.clipboardMagnet()
            model.registerWindowOpener { openWindow(id: "main") }
        }
    }

    // MARK: Downloads

    @ViewBuilder
    private var content: some View {
        let torrents = model.store.menuBarTorrents
        if case .failed = model.engine.status {
            HStack {
                Label("Download engine stopped", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Button("Restart") { Task { await model.restartEngine() } }
                    .buttonStyle(.glass)
            }
            .font(.callout)
        } else if torrents.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "arrow.down.circle.dotted")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text("No downloads")
                    .font(.callout.weight(.medium))
                Text("Click a magnet link in your browser to start.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else {
            heldStrip
            downloadList(torrents)
        }
    }

    /// Every download. Past the height limit the list scrolls, with the
    /// system's scroll bar, and fades out at an end with more past it.
    private func downloadList(_ torrents: [Torrent]) -> some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(torrents) { torrent in
                    MenuBarTorrentRow(torrent: torrent, isConfirmingDelete: Binding(
                        get: { deletingHash == torrent.hash },
                        set: { deletingHash = $0 ? torrent.hash : nil }
                    )) {
                        focusedHash = torrent.hash
                    }
                }
            }
        }
        .scrollPosition($listPosition)
        .scrollBounceBehavior(.basedOnSize)
        // As tall as the rows, up to the limit.
        .frame(maxHeight: maxListHeight)
        .fixedSize(horizontal: false, vertical: true)
        .onScrollGeometryChange(for: Edge.Set.self) { geometry in
            var edges: Edge.Set = []
            if geometry.visibleRect.minY > 1 { edges.insert(.top) }
            if geometry.visibleRect.maxY < geometry.contentSize.height - 1 { edges.insert(.bottom) }
            return edges
        } action: { _, edges in
            listEdges = edges
        }
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: listEdges.contains(.top) ? 16 : 0)
                Rectangle()
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: listEdges.contains(.bottom) ? 28 : 0)
            }
        }
        // The rows' highlight reaches out, so the list does too, rather than
        // have the scroll view clip it.
        .reachesOut()
    }

    /// A new version that's ready to install, or one found while OrbTorrent
    /// was in the background.
    @ViewBuilder
    private var updateStrip: some View {
        if let name = model.updates.ready {
            updateButton("\(AppIdentity.name) \(name) is ready", action: "Restart to Update") {
                MenuBarIcon.closePanel()
                model.updates.installReadyUpdate(showingWindow: false)
            }
        } else if let name = model.updates.waiting {
            updateButton("\(AppIdentity.name) \(name) is available", action: "Update") {
                MenuBarIcon.closePanel()
                model.updates.checkForUpdates()
            }
        }
    }

    private func updateButton(_ title: String, action: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                Text(title)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(action)
                    .foregroundStyle(.tint)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .font(.callout)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.tint.opacity(0.12), in: .rect(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.tint.opacity(0.3)))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .reachesOut()
    }

    /// Downloads a check is holding, so they aren't missed in a long list.
    @ViewBuilder
    private var heldStrip: some View {
        let held = model.extensions.isOn ? model.store.torrents.filter { model.extensions.checks.gate(for: $0.hash) == .held } : []
        if let first = held.first {
            Button {
                focusedHash = first.hash
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.orange)
                    Text(held.count == 1 ? "“\(model.store.shownName(first.name))” is held by a check" : "\(held.count) downloads are held by checks")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    Text("Review")
                        .foregroundStyle(.tint)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.callout)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.orange.opacity(0.12), in: .rect(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.orange.opacity(0.3)))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .reachesOut()
        }
    }

    @ViewBuilder
    private var clipboardButton: some View {
        if let clipboardMagnet {
            Button {
                model.adder.add(text: clipboardMagnet.uri, askingIn: .menuBar)
                self.clipboardMagnet = nil
            } label: {
                Label("Add \(clipboardMagnet.displayName.map { "“\($0)”" } ?? "Magnet Link") from Clipboard",
                      systemImage: "doc.on.clipboard")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
        }
    }

    // MARK: Footer

    private var footer: some View {
        let paused = model.store.allStopped
        // Short titles, so the three capsules share the row evenly without truncating.
        return HStack(spacing: 6) {
            Group {
                Button("Open App", systemImage: "macwindow") {
                    model.showMainWindow()
                }
                .help("Open the OrbTorrent window")

                Button(paused ? "Resume All" : "Pause All", systemImage: paused ? "play.fill" : "pause.fill") {
                    Task { paused ? await model.store.resumeAll() : await model.store.pauseAll() }
                }
                .disabled(model.store.torrents.isEmpty)
                .help(paused ? "Resume every download" : "Pause every download")

                Button("Add Link", systemImage: "plus") {
                    model.adder.presentMagnetSheet()
                }
                .help("Add a magnet link…")
            }
            .buttonStyle(.glassCapsule)

            Button("More", systemImage: "ellipsis") {
                showMoreMenu()
            }
            .buttonStyle(.glassIcon(diameter: 28))
            .help("Settings and more")
        }
    }

    private func showMoreMenu() {
        let openSettings = openSettings
        let openWindow = openWindow
        let adder = model.adder
        let updates = model.updates
        let show = { (id: String) in
            MenuBarIcon.closePanel()
            NSApp.activate()
            openWindow(id: id)
        }
        var items: [PopUpMenu.Item] = [
            .init(title: "About \(AppIdentity.name)", systemImage: "info.circle") { show("about") },
        ]
        if updates.isEnabled {
            items.append(.init(title: "Check for Updates…", systemImage: "arrow.triangle.2.circlepath") {
                MenuBarIcon.closePanel()
                updates.checkForUpdates()
            })
        }
        items += [
            .init(title: "Settings…", systemImage: "gearshape", keyEquivalent: ",") {
                MenuBarIcon.closePanel()
                NSApp.activate()
                openSettings()
            },
            .init(title: "Open Torrent File…", systemImage: "doc.badge.plus") {
                adder.presentOpenPanel(askingIn: .menuBar)
            },
            .divider,
            .init(title: "Report a Problem…", systemImage: "exclamationmark.bubble") { show("report") },
            .divider,
            .init(title: "Quit \(AppIdentity.name)", systemImage: "power", keyEquivalent: "q") {
                NSApp.terminate(nil)
            },
        ]
        PopUpMenu.show(items)
    }
}
