import AppKit
import SwiftUI

/// A torrent asked about before anything downloads: which files, and where to
/// save them. The menu bar panel and the window's sheet both show it, so the
/// two look and read the same.
struct AddConfirmation: View {
    /// Compact in the menu bar panel. In the window's sheet it's roomier, with
    /// separators across the sheet and the options the window offers.
    enum Style {
        case menuBar, window
    }

    @Environment(AppModel.self) private var model
    @Binding var pending: AddTorrentCoordinator.Pending
    var style = Style.menuBar
    /// How many torrents are waiting to be asked about, this one included.
    var waiting = 1
    let onCancel: (AddTorrentCoordinator.Pending) -> Void
    let onDownload: (AddTorrentCoordinator.Pending) -> Void
    /// Runs once a folder has been chosen: choosing can close the menu bar panel.
    var afterChoosingFolder: (() -> Void)?
    /// The checks card starts closed; its ring says how they went.
    @State private var checksOpen = false

    /// The sheet's margins; the menu bar panel has its own.
    private static let windowInset: CGFloat = 20
    private var isWindow: Bool { style == .window }
    /// The grid every row lines up on, the menu bar panel's: everything
    /// starts at the margin, boxes (the checks card, the buttons) included.
    private var largeIcon: CGFloat { isWindow ? 44 : 32 }
    private var largeGap: CGFloat { isWindow ? 14 : 10 }
    /// Checkboxes, the folder, the disk and the check ring share one size,
    /// so the text after them starts in one column.
    private var glyph: CGFloat { PanelGrid.glyph }
    private var glyphGap: CGFloat { isWindow ? 10 : PanelGrid.glyphGap }
    private var smallText: CGFloat { glyph + glyphGap }
    private var rowHeight: CGFloat { isWindow ? 30 : 26 }
    /// A long file list scrolls, showing half of the next row so it's clear there's more.
    private var maxListHeight: CGFloat { rowHeight * 7.5 }

    var body: some View {
        if isWindow {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(Self.windowInset)
                Divider()
                if let metadata = listedFiles {
                    fileList(metadata)
                        .padding(.horizontal, Self.windowInset)
                        // As far from the separators as the other sections look:
                        // the last row leaves 7 pt under its checkbox, unless
                        // it's scrolled out of sight.
                        .padding(.top, Self.windowInset - 3)
                        .padding(.bottom, scrolls(metadata) ? Self.windowInset : Self.windowInset - 7)
                    Divider()
                }
                if pending.checkState != .none && model.extensions.isOn {
                    checks
                        .padding(.horizontal, Self.windowInset)
                        .padding(.vertical, Self.windowInset - 6)
                    Divider()
                }
                bottom
                    // Its first line sits a little low in its row.
                    .padding([.horizontal, .bottom], Self.windowInset)
                    .padding(.top, Self.windowInset - 3)
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                if let metadata = listedFiles {
                    fileList(metadata)
                }
                if pending.checkState != .none && model.extensions.isOn {
                    checks
                }
                Divider()
                    // The last row already leaves 5 pt under its checkbox.
                    .padding(.top, listedFiles == nil ? 0 : -5)
                bottom
            }
        }
    }

    /// The files to pick from; a single file needs no list.
    private var listedFiles: TorrentMetadata? {
        pending.metadata.flatMap { $0.files.count > 1 ? $0 : nil }
    }

    private var bottom: some View {
        // In the window, where it goes, how it downloads, and the buttons
        // stand apart as groups of their own.
        VStack(alignment: .leading, spacing: isWindow ? 20 : 12) {
            saveFolder
            if isWindow {
                options
            }
            buttons
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: largeGap) {
            TorrentIcon(symbol: FileKind(torrentName: pending.name).symbol, size: largeIcon,
                        isLoading: isGettingFiles)
            VStack(alignment: .leading, spacing: isWindow ? 3 : 2) {
                DownloadNameText(name: pending.name)
                    .font(isWindow ? .title3.weight(.semibold) : .headline)
                    .lineLimit(2)
                    .truncationMode(.middle)
                Text(summary)
                    .font(isWindow ? .body : .caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if waiting > 1 {
                Text("1 of \(waiting)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var summary: String {
        guard let metadata = pending.metadata else {
            if isGettingFiles { return "Magnet link · getting its size and files from peers…" }
            if pending.isAskingPeers { return "Magnet link · its size and files show once your VPN connects" }
            return "Magnet link · you can pick its files once peers send the list"
        }
        guard metadata.files.count > 1 else { return Format.bytes(metadata.totalSize) }
        let files = Format.count(metadata.files.count, "file")
        return "\(files) · \(Format.bytes(selectedSize(metadata))) of \(Format.bytes(metadata.totalSize)) selected"
    }

    /// Whether a magnet link's peers are being asked for its files right now,
    /// rather than waiting for the VPN.
    private var isGettingFiles: Bool {
        pending.metadata == nil && pending.isAskingPeers && model.vpn.status != .waitingForVPN
    }

    // MARK: Files

    private func scrolls(_ metadata: TorrentMetadata) -> Bool {
        CGFloat(metadata.files.count) * rowHeight > maxListHeight
    }

    private func fileList(_ metadata: TorrentMetadata) -> some View {
        // A scroll bar that takes up room (with a mouse, or when scroll bars
        // always show) stays inside the right edge, like everything else, and
        // the sizes keep a little space from it.
        let scroller = scrolls(metadata) && NSScroller.preferredScrollerStyle == .legacy
        let problems = model.extensions.fileProblems(of: metadata.infoHash)
        let names = model.settings.shownFileNames(metadata.files.map(\.path))
        return VStack(alignment: .leading, spacing: isWindow ? 6 : 4) {
            HStack {
                Text("Files")
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Select All") { pending.setPriority(.normal, of: pending.skippedFiles) }
                Button("Select None") { pending.setPriority(.skip, of: metadata.files.map(\.id)) }
            }
            .buttonStyle(.link)
            .font(isWindow ? .callout : .caption)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(zip(metadata.files, names)), id: \.0.id) { file, name in
                        fileRow(file, shownName: name, problems: problems[file.id] ?? [])
                    }
                }
                .padding(.trailing, scroller ? 8 : 0)
            }
            // Starts at the first file, even when the list appears while the panel grows.
            .defaultScrollAnchor(.top)
            .frame(height: min(CGFloat(metadata.files.count) * rowHeight, maxListHeight))
        }
    }

    /// A file to pick, marked if a check found something wrong with it, and
    /// its priority, as in the Files tab.
    private func fileRow(_ file: TorrentMetadata.File, shownName: String?, problems: [FileFinding]) -> some View {
        HStack(spacing: glyphGap) {
            Toggle("Download", isOn: Binding(
                get: { !pending.skippedFiles.contains(file.id) },
                set: { pending.setPriority($0 ? .normal : .skip, of: [file.id]) }
            ))
            .toggleStyle(.checkbox)
            .labelsHidden()
            .frame(width: glyph, alignment: .leading)
            Text(shownName ?? (file.path as NSString).lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
                .help((file.path as NSString).lastPathComponent)
            if let worst = problems.first {
                CheckStatusIcon(status: worst.result.status, size: 12, help: problems.map(\.line).joined(separator: "\n"))
                    .accessibilityLabel(worst.line)
            }
            Spacer(minLength: 8)
            Text(Format.bytes(file.size))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            priorityMenu(file)
        }
        .font(isWindow ? .body : .callout)
        .frame(height: rowHeight)
    }

    private func priorityMenu(_ file: TorrentMetadata.File) -> some View {
        let priority = pending.priority(of: file.id)
        return Menu {
            FilePriorityPicker(selection: priority) { pending.setPriority($0, of: [file.id]) }
        } label: {
            Image(systemName: priority.symbol)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .tint(priority.color)
        .help(priority.help)
        .accessibilityLabel(priority.help)
    }

    private func selectedSize(_ metadata: TorrentMetadata) -> Int64 {
        metadata.files.filter { !pending.skippedFiles.contains($0.id) }.reduce(0) { $0 + $1.size }
    }

    // MARK: Checks

    private var checkRecords: [CheckRecord] {
        guard model.extensions.isOn, let hash = pending.metadata?.infoHash else { return [] }
        return model.extensions.checks.records(for: hash).filter { $0.event == .beforeStart }
    }

    private var hasFailedCheck: Bool {
        checkRecords.contains { $0.status == .failed }
    }

    /// Extensions' checks, which run once the files are known.
    private var checks: some View {
        // Still waiting counts as checking, before the first result arrives.
        let summary = CheckSummary(records: checkRecords, gate: pending.checkState == .checking ? .waiting : nil)
        return VStack(alignment: .leading, spacing: isWindow ? 10 : 8) {
            ChecksCard(summary: summary, isOpen: $checksOpen, iconSize: isWindow ? 24 : 22)
            if hasFailedCheck {
                Text("If you didn't expect this, cancel. Download Anyway starts it as it is.")
                    .font(isWindow ? .callout : .caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, smallText)
            }
        }
    }

    // MARK: Folder

    private var saveFolder: some View {
        VStack(alignment: .leading, spacing: isWindow ? 8 : 6) {
            HStack(alignment: .firstTextBaseline, spacing: glyphGap) {
                // Left in its slot, so its edge meets the checkboxes' above.
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
                    .frame(width: glyph, alignment: .leading)
                Text("Save to \(FileManager.default.displayName(atPath: saveFolderPath))")
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(saveFolderPath)
                Spacer(minLength: 8)
                Button("Change…", action: chooseFolder)
                    .buttonStyle(.link)
            }
            DiskSpaceLine(pending: pending, iconColumn: glyph, iconWidth: glyph, gap: glyphGap)
        }
        .font(isWindow ? .body : .caption)
    }

    private var saveFolderPath: String {
        model.adder.saveFolder(for: pending)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.directoryURL = URL(fileURLWithPath: saveFolderPath, isDirectory: true)
        NSApp.activate()
        if panel.runModal() == .OK, let url = panel.url {
            pending.saveFolder = url
        }
        afterChoosingFolder?()
    }

    // MARK: Options

    private var options: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Start right away", isOn: $pending.startImmediately)
            Toggle("Download in order, to watch while it downloads", isOn: $pending.sequentialDownload)
        }
        .toggleStyle(.checkbox)
    }

    // MARK: Buttons

    private var downloadTitle: String {
        if pending.checkState == .checking { return "Checking…" }
        return hasFailedCheck ? "Download Anyway" : "Download"
    }

    private var buttons: some View {
        HStack(spacing: isWindow ? 10 : 6) {
            Button("Cancel") {
                onCancel(pending)
            }
            .buttonStyle(.glassCapsule)
            .keyboardShortcut(.cancelAction)

            Button(downloadTitle, systemImage: "arrow.down") {
                onDownload(pending)
            }
            .buttonStyle(.glassCapsule(prominent: !hasFailedCheck))
            .keyboardShortcut(.defaultAction)
            .disabled(pending.checkState == .checking
                      || (pending.metadata.map { pending.skippedFiles.count == $0.files.count } ?? false))
        }
        .controlSize(isWindow ? .large : .regular)
    }
}
