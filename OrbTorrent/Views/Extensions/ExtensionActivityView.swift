import AppKit
import SwiftUI

/// The Activity tab: downloads a check is holding, and every check on every
/// download.
struct ExtensionActivityView: View {
    @Environment(AppModel.self) private var model
    @State private var sortOrder = [KeyPathComparator(\RecentCheck.date, order: .reverse)]
    @State private var selection: Set<RecentCheck.ID> = []

    private var search: String { model.extensionSearch.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        let all = RecentCheck.list(from: model.extensions.checks, names: { model.store.torrent($0)?.name })
        let rows = filtered(all).sorted(using: sortOrder)
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HeldDownloadsView()
                filters(showing: rows.count, of: all.count)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 10)
            table(rows)
                .overlay { empty(all: all, rows: rows) }
        }
        .navigationSubtitle(all.isEmpty ? "" : Format.count(all.count, "check"))
    }

    private func filtered(_ checks: [RecentCheck]) -> [RecentCheck] {
        let filter = model.activityFilter
        return checks.filter { check in
            (!filter.problemsOnly || check.isProblem)
                && (filter.extensionName == nil || check.record.extensionName == filter.extensionName)
                && (search.isEmpty || [check.downloadName, check.extensionTitle, check.summary].contains { $0.localizedStandardContains(search) })
        }
    }

    private func filters(showing count: Int, of total: Int) -> some View {
        @Bindable var model = model
        return HStack(spacing: 12) {
            Picker("Show", selection: $model.activityFilter.problemsOnly) {
                Text("All Checks").tag(false)
                Text("Problems").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Picker("Extension", selection: $model.activityFilter.extensionName) {
                Text("All Extensions").tag(String?.none)
                Divider()
                ForEach(model.extensions.registry.extensions) { item in
                    Text(item.title).tag(Optional(item.name))
                }
            }
            .labelsHidden()
            .fixedSize()
            Spacer(minLength: 8)
            // The subtitle has the total; this says how many a filter leaves.
            if count != total {
                Text("\(count) of \(Format.count(total, "check"))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func table(_ rows: [RecentCheck]) -> some View {
        Table(rows, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Status", value: \.severity) { check in
                HStack(spacing: 6) {
                    CheckStatusIcon(status: check.record.status)
                    Text(check.record.status.title)
                }
            }
            .width(min: 90, ideal: 110, max: 140)
            TableColumn("Download", value: \.downloadName) { check in
                Text(check.downloadName)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(check.downloadName)
            }
            .width(min: 140, ideal: 240)
            TableColumn("Extension", value: \.extensionTitle) { check in
                Text(check.extensionTitle)
                    .lineLimit(1)
            }
            .width(min: 100, ideal: 150)
            TableColumn("Result", value: \.summary) { check in
                Text(check.summary)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .help(check.summary)
            }
            .width(min: 160, ideal: 320)
            TableColumn("When", value: \.date) { check in
                Group {
                    if check.record.status.isFinished, let finished = check.record.finishedAt {
                        Text(finished, format: .relative(presentation: .named))
                    } else {
                        Text("Now")
                    }
                }
                .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 110, max: 150)
        }
        .contextMenu(forSelectionType: RecentCheck.ID.self) { ids in
            menu(for: rows.filter { ids.contains($0.id) })
        } primaryAction: { ids in
            if let check = rows.first(where: { ids.contains($0.id) }) { model.showChecks(of: check.hash) }
        }
    }

    @ViewBuilder
    private func menu(for checks: [RecentCheck]) -> some View {
        if checks.count == 1, let check = checks.first {
            let registry = model.extensions.registry
            let item = registry.named(check.record.extensionName)
            let hook = item?.manifest.hooks.first { $0.name == check.record.hookName }
            let torrent = model.store.torrent(check.hash)
            Button("Show Download's Checks") { model.showChecks(of: check.hash) }
            if let item {
                Button("Show \(item.title)") { model.showExtensions(item.name) }
            }
            if let item, let hook, let torrent, check.record.status.isFinished,
               hook.event == .beforeStart || torrent.isComplete {
                Button("Run Again") { Task { await model.extensions.runAgain(item, hook, on: torrent) } }
            }
            Divider()
            Button("Copy Result") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("\(check.downloadName): \(check.extensionTitle): \(check.summary)", forType: .string)
            }
        }
    }

    @ViewBuilder
    private func empty(all: [RecentCheck], rows: [RecentCheck]) -> some View {
        if all.isEmpty {
            ContentUnavailableView("No Checks Yet", systemImage: "checkmark.shield",
                                   description: Text("Results show here as extensions check your downloads.").font(.callout))
        } else if rows.isEmpty {
            if !search.isEmpty {
                ContentUnavailableView.search(text: search)
            } else {
                ContentUnavailableView {
                    Label(model.activityFilter.problemsOnly ? "No Problems Found" : "No Checks", systemImage: "checkmark.circle")
                } description: {
                    Text(model.activityFilter.problemsOnly
                         ? "No check has failed, warned or not finished."
                         : "This extension hasn't checked a download yet.")
                    .font(.callout)
                } actions: {
                    Button("Show All Checks") { model.activityFilter = ActivityFilter() }
                }
            }
        }
    }
}

/// Downloads a check is holding, so they're hard to miss.
private struct HeldDownloadsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let checks = model.extensions.checks
        let held = checks.gated.filter { $0.value == .held }.keys
            .compactMap(model.store.torrent)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if !held.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label(held.count == 1 ? "Holding a download before it starts" : "Holding \(held.count) downloads before they start",
                      systemImage: "hand.raised.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                ForEach(held) { torrent in
                    let failed = checks.records(for: torrent.hash).filter { $0.event == .beforeStart && $0.status == .failed }
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(torrent.name)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if let first = failed.first {
                                Text("\(first.extensionTitle): \(first.summary)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 8)
                        Button("Review") { model.showChecks(of: torrent.hash) }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.1), in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.orange.opacity(0.3)))
        }
    }
}
