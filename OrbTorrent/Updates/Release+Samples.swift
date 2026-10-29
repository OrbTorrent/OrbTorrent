import Foundation

extension Release {
    /// Notes to look at What's New with in OrbTorrent Dev, which has none
    /// until it reads a feed. Two releases, as after skipping an update, with
    /// every kind of section. Never shown in OrbTorrent.
    static let samples: [Release] = [
        Release(
            build: "2", version: "1.0", title: "1.0 (sample notes)", date: .now,
            notes: """
            Sample notes, to see how What's New looks in OrbTorrent Dev.

            ## New

            - **Lives in your menu bar.** The orb fills up as your downloads progress, and changes colour when something needs you.
            - **Download only through a VPN.** If the VPN drops, downloading stops, and picks up the moment it's back.
            - **Holds fake downloads before they arrive.** The Fake Download Check looks at a download's files before any of them arrive.

            ## Improved

            - **Each section has its own look,** from its heading: New, Improved, Fixed and Known issues.

            ## Fixed

            - **A bold first phrase** becomes the item's title, as in a GitHub release's notes.

            ## Known issues

            - **These notes are a sample,** shown only in OrbTorrent Dev.
            """,
            link: URL(string: "https://github.com/orbtorrent/OrbTorrent/releases")),
        Release(
            build: "1", version: "1.0", title: "1.0 beta (sample notes)", date: nil,
            notes: """
            ## New

            - **Brings your downloads over** from Transmission or qBittorrent, with their progress and settings.
            """,
            link: nil),
    ]
}
