// The questions people ask, for the FAQ page, the home page and their
// structured data. Answers are plain text, as search engines show them.

export interface Faq {
  question: string;
  answer: string;
}

export const faqs: Faq[] = [
  {
    question: "Is OrbTorrent free?",
    answer: "Yes. OrbTorrent is free and open source, under the GNU General Public License. There are no ads, no account and nothing to buy.",
  },
  {
    question: "Is it legal to use?",
    answer: "Using BitTorrent is legal. It's how Linux, open films and large public datasets are shared. What you download is up to you: download and share only what you have the right to.",
  },
  {
    question: "How does it use qBittorrent?",
    answer: "OrbTorrent bundles qBittorrent's engine, built from its released source, and runs it in the background. It talks to the engine through qBittorrent's Web API, which only accepts connections from your Mac. OrbTorrent isn't affiliated with or endorsed by the qBittorrent project.",
  },
  {
    question: "Which Macs does it run on?",
    answer: "Any Mac with macOS 26 (Tahoe) or later, with Apple silicon or Intel. It's one universal app.",
  },
  {
    question: "Does it work with my VPN?",
    answer: "Yes. Turn on Only download through a VPN, and OrbTorrent uses only the VPN's connection, stopping if the VPN drops. It finds VPN apps and tunnels such as Tunnelblick and WireGuard, picks up forwarded ports from VPNs that use NAT-PMP and from Private Internet Access, and uses a reserved port, as AirVPN and Windscribe give you, once you enter it.",
  },
  {
    question: "Does OrbTorrent collect any data?",
    answer: "Only anonymous counts, never an ID. Its daily check for updates says which version it is, your version of macOS, the kind of Mac, the week it was installed and how often it quit unexpectedly, so we know how many Macs use it and whether a version has a problem. Nothing about how you use it is sent. There's no account and no crash reporting, Settings shows exactly what's sent and turns it off, and the privacy page lists everything.",
  },
  {
    question: "My internet provider shares my IP address. Will OrbTorrent still find peers?",
    answer: "Yes. When your provider shares one public address between customers, known as carrier-grade NAT, no port can be opened, so other peers can't connect to you directly. OrbTorrent's engine still reaches many of them by hole punching: a peer you're both connected to introduces you, and you connect to each other at the same moment. For every peer to reach you, use a VPN that forwards a port, and OrbTorrent keeps it in step by itself.",
  },
  {
    question: "Can I bring my downloads over from Transmission or qBittorrent?",
    answer: "Yes. OrbTorrent offers to when you first open it, or later from File › Import From. Downloads keep their folders, file choices, names, labels, limits and history, and you choose which of the app's settings come over.",
  },
  {
    question: "Does it work with private trackers?",
    answer: "Yes. OrbTorrent never adds trackers to a private torrent, and leaves it exactly as it came.",
  },
  {
    question: "Why does it need macOS 26?",
    answer: "It's built with the SwiftUI and Liquid Glass that came with macOS 26, so it fits in with the rest of your Mac. It runs on macOS 26 and every version since. One app done well, rather than two done halfway.",
  },
  {
    question: "Is it an Electron app?",
    answer: "No. It's written in Swift and SwiftUI, and its engine is qBittorrent's, built from source.",
  },
  {
    question: "How do I uninstall it?",
    answer: "Quit OrbTorrent and drag it to the Trash. Your library and settings are in ~/Library/Application Support/OrbTorrent, if you'd like them gone too. Your downloaded files stay where they are.",
  },
  {
    question: "What's coming next?",
    answer: "Playing videos while they download, and remote access. The roadmap on GitHub lists what's planned, and what's been put off and why.",
  },
  {
    question: "How do I report a problem?",
    answer: "Choose Help › Report a Problem in the app, which fills in the details that help, or open an issue on GitHub. Please report security problems privately, to help@orbtorrent.com.",
  },
];
