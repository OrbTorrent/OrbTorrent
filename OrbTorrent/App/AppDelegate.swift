import AppKit

/// Handles app-level events SwiftUI doesn't expose: opening URLs and files,
/// clicking the Dock or Finder icon again, and quitting cleanly.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel
    private var addConfirmationPanel: AddConfirmationPanel?
    private var isTerminating = false
    private var launchedAsLoginItem = false

    override init() {
        model = AppModel()
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Only one OrbTorrent may drive the engine; hand over to a copy already running.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let running = others.first,
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            running.activate()
            exit(0)
        }

        if let event = NSAppleEventManager.shared().currentAppleEvent,
           event.eventID == kAEOpenApplication,
           event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem {
            launchedAsLoginItem = true
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // When hosting unit tests, don't start the engine or open windows.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        let confirmationPanel = AddConfirmationPanel(model: model)
        addConfirmationPanel = confirmationPanel
        model.adder.showMenuBarConfirmation = { [weak confirmationPanel] in
            Task { await confirmationPanel?.show() }
        }
        model.adder.showMenuBarDownloads = { [weak confirmationPanel] in
            confirmationPanel?.showDownloads()
        }
        model.counts.appDidLaunch()
        // Back from installing an update, it stays in the menu bar, unless
        // it was restarted from its window.
        if let showsWindow = model.updates.takeRelaunchAfterUpdate() {
            if showsWindow { model.showMainWindow() }
        } else if !launchedAsLoginItem {
            model.showMainWindow()
        }
        Task { await model.launch() }
    }

    /// Links and files opened from other apps are asked about in the menu bar.
    func application(_ application: NSApplication, open urls: [URL]) {
        model.adder.open(urls, askingIn: .menuBar)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        model.showMainWindow()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Lets the engine save resume data before OrbTorrent exits.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isTerminating else { return .terminateLater }
        isTerminating = true
        Task {
            await model.shutdown()
            model.counts.appWillQuit()
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
