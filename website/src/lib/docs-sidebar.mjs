// The docs' sidebar, in reading order. The config draws it, and llms.txt
// and llms-full.txt follow the same order.

/** @type {import("@astrojs/starlight/types").StarlightUserConfig["sidebar"]} */
export const sidebar = [
  { label: "Docs", link: "/docs" },
  {
    label: "Get started",
    items: [
      { label: "Install OrbTorrent", link: "/docs/get-started/install" },
      { label: "Your first download", link: "/docs/get-started/first-download" },
      { label: "Magnet links and .torrent files", link: "/docs/get-started/magnet-links" },
      { label: "Switch from another app", link: "/docs/get-started/switch" },
    ],
  },
  {
    label: "Use OrbTorrent",
    items: [
      { label: "The menu bar", link: "/docs/guides/menu-bar" },
      { label: "The library window", link: "/docs/guides/library" },
      { label: "A download's details", link: "/docs/guides/download-details" },
      { label: "Choose files and their order", link: "/docs/guides/files" },
      { label: "Checks and held downloads", link: "/docs/guides/checks" },
      { label: "Notifications", link: "/docs/guides/notifications" },
      { label: "Run your own program", link: "/docs/guides/run-a-program" },
      { label: "Updates", link: "/docs/guides/updates" },
    ],
  },
  {
    label: "Network and privacy",
    items: [
      { label: "Download only through a VPN", link: "/docs/guides/vpn" },
      { label: "Port forwarding", link: "/docs/guides/port-forwarding" },
      { label: "Find more peers", link: "/docs/guides/peers" },
      { label: "Speed limits and sharing", link: "/docs/guides/speed-and-sharing" },
      { label: "Disk space", link: "/docs/guides/disk-space" },
      { label: "Privacy", link: "/docs/guides/privacy" },
    ],
  },
  {
    label: "Reference",
    items: [
      { label: "Settings", link: "/docs/reference/settings" },
      { label: "Menus and shortcuts", link: "/docs/reference/shortcuts" },
      { label: "Files on your Mac", link: "/docs/reference/files" },
    ],
  },
  {
    label: "Help",
    items: [
      { label: "Troubleshooting", link: "/docs/help/troubleshooting" },
      { label: "Report a problem", link: "/docs/help/report-a-problem" },
      { label: "Uninstall", link: "/docs/help/uninstall" },
      { label: "Questions and answers", link: "/faq", attrs: { "data-external": "" } },
    ],
  },
  {
    label: "Build extensions",
    items: [
      { label: "Overview", link: "/docs/extensions" },
      { label: "Your first extension", link: "/docs/extensions/getting-started" },
      { label: "Build with a coding agent", link: "/docs/extensions/coding-agents" },
      {
        label: "Concepts",
        items: [
          { label: "Hooks", link: "/docs/extensions/hooks" },
          { label: "Results", link: "/docs/extensions/results" },
          { label: "Settings", link: "/docs/extensions/settings" },
          { label: "Network requests", link: "/docs/extensions/network" },
          { label: "Read and add files", link: "/docs/extensions/files" },
          { label: "Storage and progress", link: "/docs/extensions/storage" },
        ],
      },
      {
        label: "Workflow",
        items: [
          { label: "Testing", link: "/docs/extensions/testing" },
          { label: "Run and debug", link: "/docs/extensions/debugging" },
          { label: "Share and install", link: "/docs/extensions/sharing" },
          { label: "Security model", link: "/docs/extensions/security" },
          { label: "Examples", link: "/docs/extensions/examples" },
        ],
      },
      {
        label: "Reference",
        items: [
          { label: "API", link: "/docs/extensions/reference/api" },
          { label: "orb command", link: "/docs/extensions/reference/cli" },
          { label: "Manifest", link: "/docs/extensions/reference/manifest" },
          { label: "Test files", link: "/docs/extensions/reference/tests" },
          { label: "Limits", link: "/docs/extensions/reference/limits" },
          { label: "Errors and fixes", link: "/docs/extensions/reference/errors" },
          { label: "Changelog", link: "/docs/extensions/reference/changelog" },
        ],
      },
    ],
  },
  {
    label: "Contribute",
    items: [
      { label: "How OrbTorrent works", link: "/docs/contribute/how-it-works" },
      { label: "Contribute to OrbTorrent", link: "/docs/contribute" },
    ],
  },
];

/**
 * Every page in the sidebar, with the groups it's in, outermost first.
 * @param {any[]} [items]
 * @param {string[]} [groups]
 * @returns {{ label: string, link: string, groups: string[] }[]}
 */
export function sidebarPages(items = sidebar, groups = []) {
  return items.flatMap((item) =>
    "items" in item ? sidebarPages(item.items, [...groups, item.label]) : [{ label: item.label, link: item.link, groups }],
  );
}
