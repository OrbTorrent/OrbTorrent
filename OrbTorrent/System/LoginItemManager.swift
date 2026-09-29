import Observation
import ServiceManagement

/// Starts OrbTorrent when the user logs in, via the system Login Items list.
@MainActor
@Observable
final class LoginItemManager {
    private(set) var isEnabled = false
    private(set) var needsApproval = false

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        needsApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        defer { refresh() }
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
