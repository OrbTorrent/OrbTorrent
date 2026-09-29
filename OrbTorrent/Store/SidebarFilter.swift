import Foundation

/// The library sections shown in the sidebar.
enum SidebarFilter: String, CaseIterable, Identifiable, Hashable {
    case all, downloading, seeding, completed, paused, errors

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All Downloads"
        case .downloading: "Downloading"
        case .seeding: "Seeding"
        case .completed: "Completed"
        case .paused: "Paused"
        case .errors: "Needs Attention"
        }
    }

    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .downloading: "arrow.down.circle"
        case .seeding: "arrow.up.circle"
        case .completed: "checkmark.circle"
        case .paused: "pause.circle"
        case .errors: "exclamationmark.triangle"
        }
    }

    func includes(_ torrent: Torrent) -> Bool {
        switch self {
        case .all:
            return true
        case .downloading:
            return !torrent.isComplete && !torrent.state.isStopped && torrent.state.activity != .error
        case .seeding:
            return torrent.state.activity == .seeding
        case .completed:
            return torrent.isComplete
        case .paused:
            return torrent.state.isStopped
        case .errors:
            return torrent.state.activity == .error
        }
    }
}

/// What the main window shows: the library, or the Extensions page.
enum MainSection: Hashable {
    case library, extensions
}

/// The Extensions page's tabs.
enum ExtensionsTab: String, CaseIterable, Identifiable {
    case installed, activity, develop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installed: "Installed"
        case .activity: "Activity"
        case .develop: "Develop"
        }
    }
}

/// Which checks the Activity tab lists.
struct ActivityFilter: Equatable {
    var problemsOnly = false
    /// Only this extension's checks, by name.
    var extensionName: String?
}
