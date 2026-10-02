// llms.txt and llms-full.txt (https://llmstxt.org): what's on orbtorrent.com,
// for language models, and the docs in full.

import { getCollection } from "astro:content";
import { site } from "./site";
import { sidebarPages } from "./docs-sidebar.mjs";
import { pageMarkdown } from "./docs-markdown";

const summary =
  "OrbTorrent is a free, open-source torrent app for the Mac (macOS 26 or later, Apple silicon and Intel). It's a native Swift and SwiftUI app that runs qBittorrent's engine, lives in the menu bar, can download only through a VPN, and holds fake downloads before they arrive. Extensions, written in TypeScript with @orbtorrent/api, check downloads before they start and after they finish. GPL-licensed, with no ads, no account and no tracking: only anonymous counts, without an ID, with its update check.";

const welcome =
  "This website and its docs are open source too. Search engines and AI tools are welcome to use everything on it, including to answer questions and to train on.";

/** The docs pages in sidebar order, with the groups each is in. */
async function docs(within?: string) {
  const entries = await getCollection("docs");
  const byPath = new Map(entries.map((entry) => [`/${entry.id}`, entry]));
  return sidebarPages()
    .filter((page) => byPath.has(page.link) && (!within || page.link === within || page.link.startsWith(`${within}/`)))
    .map((page) => ({ ...page, entry: byPath.get(page.link)! }));
}

function sections(pages: Awaited<ReturnType<typeof docs>>, drop = 0): string[] {
  const lines: string[] = [];
  let heading = "";
  for (const page of pages) {
    const group = page.groups.slice(drop).join(": ") || "Start";
    if (group !== heading) {
      lines.push("", `## ${group}`, "");
      heading = group;
    }
    lines.push(`- [${page.entry.data.title}](${site.url}/${page.entry.id}.md): ${page.entry.data.description}`);
  }
  return lines;
}

/** The whole site: its pages, then the docs, each as Markdown. */
export async function llmsIndex(): Promise<string> {
  return [
    `# ${site.name}`,
    "",
    `> ${summary}`,
    "",
    welcome,
    "",
    "Each docs page is also Markdown, at its address plus .md. All of the docs together are in [llms-full.txt](https://orbtorrent.com/llms-full.txt), and the extension docs alone in [docs/extensions/llms-full.txt](https://orbtorrent.com/docs/extensions/llms-full.txt).",
    "",
    "## Website",
    "",
    `- [Home](${site.url}/): what OrbTorrent does, with the features.`,
    `- [Download](${site.url}/download): the newest version, what it needs, how to install it (or \`brew install orbtorrent/tap/orbtorrent\`) and uninstall it.`,
    `- [Extensions](${site.url}/extensions): the Fake Download Check, VirusTotal Scan, and building your own in TypeScript.`,
    `- [Switch from Transmission or qBittorrent](${site.url}/switch): what comes over when importing.`,
    `- [Privacy](${site.url}/privacy): everything the app and the website connect to.`,
    `- [FAQ](${site.url}/faq): questions and answers.`,
    `- [Press kit](${site.url}/press): facts, descriptions and images.`,
    ...sections(await docs()),
    "",
    "## Optional",
    "",
    `- [Source code](${site.repo}): the app, the extension SDK, the official extensions and this website.`,
    "- [@orbtorrent/api on npm](https://www.npmjs.com/package/@orbtorrent/api): the extension API and the `orb` command-line tool.",
    `- [Agent Skill](${site.repo}/tree/main/skills/build-orbtorrent-extension): for coding agents building an extension.`,
    "",
  ].join("\n");
}

/** Just the extension docs, for coding agents building one. */
export async function llmsExtensionsIndex(): Promise<string> {
  return [
    "# OrbTorrent Extensions",
    "",
    "> Extensions hook into moments in a download's life in OrbTorrent, a BitTorrent app for macOS: before it starts (and can hold it) or after it finishes. They're TypeScript, run in a sandboxed JavaScriptCore host, and reach the network, files and storage only through @orbtorrent/api.",
    "",
    "Every page here is Markdown. All of them together are in [llms-full.txt](https://orbtorrent.com/docs/extensions/llms-full.txt).",
    ...sections(await docs("/docs/extensions"), 1),
    "",
    "## For coding agents",
    "",
    `- [AGENTS.md](${site.repo}/blob/main/sdk/templates/_shared/AGENTS.md): the whole API, the rules and the loop, in one file. Every extension made with \`orb create\` has it.`,
    `- [Agent Skill](${site.repo}/tree/main/skills/build-orbtorrent-extension): for Claude Code, Codex, Cursor and other agents that use the Agent Skills format.`,
    "",
  ].join("\n");
}

/** Pages in full, one after another. */
export async function llmsFull(within?: string): Promise<string> {
  const pages = await docs(within);
  const intro = within
    ? "# OrbTorrent Extensions: the docs in full\n\n> Everything about building extensions for OrbTorrent, from orbtorrent.com/docs/extensions.\n"
    : `# OrbTorrent: the docs in full\n\n> ${summary}\n\n${welcome}\n`;
  return [intro, ...pages.map((page) => pageMarkdown(page.entry))].join("\n---\n\n");
}

export const text = (body: string) => new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
