import SwiftUI

@main
struct OrbTorrentApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window(AppIdentity.name, id: "main") {
            MainWindowView()
                .environment(appDelegate.model)
        }
        .defaultSize(width: 1_120, height: 700)
        .defaultLaunchBehavior(.suppressed)
        // Links and files opened from other apps are asked about in the menu
        // bar (AppDelegate). Every window turns them down, or SwiftUI would
        // show the first one that doesn't, such as About.
        .handlesExternalEvents(matching: [])
        .commands { OrbTorrentCommands(model: appDelegate.model) }

        MenuBarExtra {
            MenuBarPanel()
                .environment(appDelegate.model)
        } label: {
            MenuBarLabel()
                .environment(appDelegate.model)
        }
        .menuBarExtraStyle(.window)

        Window("About \(AppIdentity.name)", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])

        Window("Report a Problem", id: "report") {
            ReportProblemView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .handlesExternalEvents(matching: [])

        Settings {
            SettingsView()
                .environment(appDelegate.model)
        }
        .handlesExternalEvents(matching: [])
    }
}
