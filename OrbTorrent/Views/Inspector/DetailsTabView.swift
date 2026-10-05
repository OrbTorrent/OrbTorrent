import AppKit
import SwiftUI

/// Transfer statistics, options and torrent metadata.
struct DetailsTabView: View {
    @Environment(AppModel.self) private var model
    let torrent: Torrent
    @State private var properties: TorrentProperties?

    var body: some View {
        Form {
            Section("Transfer") {
                LabeledContent("Size", value: sizeText)
                LabeledContent("Downloaded", value: Format.bytes(torrent.downloaded))
                LabeledContent("Uploaded", value: Format.bytes(torrent.uploaded))
                LabeledContent("Ratio", value: Format.ratio(torrent.ratio))
                LabeledContent("Seeds", value: "\(torrent.connectedSeeds) connected of \(torrent.swarmSeeds)")
                LabeledContent("Peers", value: "\(torrent.connectedPeers) connected of \(torrent.swarmPeers)")
                if torrent.availability >= 0 {
                    LabeledContent("Availability", value: Format.ratio(torrent.availability))
                }
                if let properties {
                    LabeledContent("Time Active", value: Format.duration(properties.timeActive))
                    LabeledContent("Average Speed", value: Format.speed(properties.averageDownloadSpeed))
                    if properties.wasted > 0 {
                        LabeledContent("Wasted", value: Format.bytes(properties.wasted))
                    }
                }
            }
            .monospacedDigit()

            Section("Options") {
                Toggle("Download pieces in order", isOn: Binding(
                    get: { torrent.sequentialDownload },
                    set: { _ in Task { await model.store.toggleSequentialDownload(torrent) } }
                ))
                .help("Useful for watching a video while it downloads.")
                Toggle("Get first and last pieces first", isOn: Binding(
                    get: { torrent.firstLastPiecePriority },
                    set: { _ in Task { await model.store.toggleFirstLastPiecePriority(torrent) } }
                ))
                .help("Lets media players read a file's header and index early.")
            }

            Section("Location") {
                LabeledContent("Saved In") {
                    HStack(spacing: 6) {
                        Text(torrent.savePath)
                            .lineLimit(1)
                            .truncationMode(.head)
                            .textSelection(.enabled)
                        Button("Show", systemImage: "arrow.right.circle.fill") {
                            FileActions.reveal(torrent)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section("Torrent") {
                LabeledContent("Name") {
                    Text(torrent.name)
                        .textSelection(.enabled)
                }
                LabeledContent("Added", value: Format.date(torrent.addedOn))
                if torrent.completedOn != nil {
                    LabeledContent("Completed", value: Format.date(torrent.completedOn))
                }
                if let properties {
                    if properties.createdOn != nil {
                        LabeledContent("Created", value: Format.date(properties.createdOn))
                    }
                    if !properties.createdBy.isEmpty {
                        LabeledContent("Created By", value: properties.createdBy)
                    }
                    if properties.piecesTotal > 0 {
                        LabeledContent("Pieces",
                                       value: "\(properties.piecesHave) of \(properties.piecesTotal) × \(Format.bytes(properties.pieceSize))")
                    }
                    LabeledContent("Private", value: properties.isPrivate ? "Yes" : "No")
                    if !properties.comment.isEmpty {
                        LabeledContent("Comment") {
                            Text(properties.comment).textSelection(.enabled)
                        }
                    }
                }
                LabeledContent("Info Hash") {
                    Text(torrent.hash)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Section {
                Button("Copy Name", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(torrent.name, forType: .string)
                }
                Button("Copy Magnet Link", systemImage: "link") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(torrent.magnetURI, forType: .string)
                }
                Button("Ask Trackers for More Peers", systemImage: "antenna.radiowaves.left.and.right") {
                    Task { await model.store.reannounce([torrent.hash]) }
                }
                Button("Verify Local Data", systemImage: "checkmark.shield") {
                    Task { await model.store.recheck([torrent.hash]) }
                }
            }
        }
        .formStyle(.grouped)
        .task(id: torrent.hash) {
            while !Task.isCancelled {
                properties = try? await model.store.properties(of: torrent.hash)
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private var sizeText: String {
        torrent.size == torrent.totalSize
            ? Format.bytes(torrent.size)
            : "\(Format.bytes(torrent.size)) selected of \(Format.bytes(torrent.totalSize))"
    }
}
