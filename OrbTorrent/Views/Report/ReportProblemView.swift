import AppKit
import SwiftUI

/// Report a Problem, from the Help menu and the menu bar's ⋯ menu: a short
/// form, and everything that goes with it shown in full. It opens the
/// person's mail app with the report filled in; nothing is sent on its own.
struct ReportProblemView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var report = ProblemReport()
    @State private var log = ""
    @State private var didCopy = false
    @State private var mailFailed = false
    @FocusState private var isWriting: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                TorrentIcon(symbol: "exclamationmark.bubble", size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Report a Problem")
                        .font(.title2.weight(.bold))
                    Text("It goes to \(ProblemReport.address) from your own mail app, only when you send it.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What happened?")
                    .font(.headline)
                TextEditor(text: $report.description)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($isWriting)
                    .padding(8)
                    .frame(height: 120)
                    .background(.background.secondary, in: .rect(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        if report.description.isEmpty {
                            Text("What you were doing, what you expected, and what happened instead.")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Sent with it")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 10) {
                    Text(ProblemReport.details.joined(separator: "\n"))
                        .font(.system(size: 11.5, design: .monospaced))
                        .textSelection(.enabled)
                    Divider()
                    Toggle(isOn: $report.includesLog.animation(.smooth)) {
                        Text("Include the engine's recent log")
                        Text("Its last \(ProblemReport.logLines) lines, which often show what went wrong. IP addresses and your user name are hidden, but it can name your downloads.")
                    }
                    if report.includesLog {
                        ScrollView {
                            Text(log)
                                .font(.system(size: 10.5, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 130)
                        .defaultScrollAnchor(.bottom)
                        .transition(.opacity)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }

            HStack(spacing: 10) {
                Button(didCopy ? "Copied" : "Copy Report") { copy() }
                    .buttonStyle(.glass)
                Spacer()
                Button("Cancel") { dismissWindow() }
                    .buttonStyle(.glass)
                    .keyboardShortcut(.cancelAction)
                Button("Open in Mail") { openInMail() }
                    .buttonStyle(.glassProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isBlank)
            }
            .controlSize(.large)
        }
        .padding(24)
        .padding(.top, 8)
        .frame(width: 540)
        .onAppear {
            log = ProblemReport.recentLog()
            isWriting = true
        }
        .onChange(of: report.includesLog) { _, includes in
            if includes { log = ProblemReport.recentLog() }
        }
        .alert("Your Mail App Couldn't Open", isPresented: $mailFailed) {
            Button("Copy Report") { copy() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Copy the report instead, and email it to \(ProblemReport.address).")
        }
    }

    private var isBlank: Bool {
        report.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report.text(log: log), forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            didCopy = false
        }
    }

    private func openInMail() {
        guard let url = report.mailURL(log: log), NSWorkspace.shared.open(url) else {
            mailFailed = true
            return
        }
        report = ProblemReport()
        dismissWindow()
    }
}
