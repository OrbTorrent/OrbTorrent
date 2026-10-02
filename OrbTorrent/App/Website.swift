import Foundation

/// OrbTorrent's pages on orbtorrent.com, which the app links to: a domain we
/// control, so the links keep working wherever the code moves.
enum Website {
    static let home = URL(string: "https://orbtorrent.com")!
    static let docs = URL(string: "https://orbtorrent.com/docs")!
    static let troubleshooting = URL(string: "https://orbtorrent.com/docs/help/troubleshooting")!
    static let counts = URL(string: "https://orbtorrent.com/privacy#counts")!
    static let finishedProgram = URL(string: "https://orbtorrent.com/docs/guides/run-a-program")!
}
