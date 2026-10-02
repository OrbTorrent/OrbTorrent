// The docs as plain Markdown, for language models and anyone who'd rather
// read the source: each page at its address plus .md, and all of them
// together in llms-full.txt.

import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { CollectionEntry } from "astro:content";
import { site } from "./site";

type Entry = CollectionEntry<"docs">;

/** The SDK's changelog, which the docs' Changelog page shows from sdk/. */
const changelog = () =>
  readFileSync(join(process.cwd(), "..", "sdk", "CHANGELOG.md"), "utf8").replace(/^# .*\n+/, "").trim();

const attribute = (tag: string, name: string) => tag.match(new RegExp(`${name}="([^"]*)"`))?.[1];

/** A page's Markdown, with MDX's components written out as plain Markdown. */
export function pageMarkdown(entry: Entry): string {
  let body = entry.body ?? "";
  if (entry.filePath?.endsWith(".mdx")) {
    body = body
      .replace(/^import .*$/gm, "")
      .replace(/^[ \t]*<LinkCard\b[^>]*\/>/gm, (tag) => {
        const description = attribute(tag, "description");
        return `- [${attribute(tag, "title")}](${attribute(tag, "href")})${description ? `: ${description}` : ""}`;
      })
      .replace(/^[ \t]*<Card\b[^>]*>/gm, (tag) => `#### ${attribute(tag, "title")}\n`)
      .replace(/<TabItem\b[^>]*>/g, (tag) => `**${attribute(tag, "label")}**\n`)
      .replace(/<SdkChangelog\s*\/>/g, changelog())
      // What's left is layout: steps, grids, tabs and the like.
      .replace(/^\s*<\/?[A-Z][A-Za-z]*\b[^>]*>\s*$/gm, "");
  }
  body = body
    // Asides, as GitHub writes them.
    .replace(/^:::(note|tip|caution|danger)(?:\[([^\]]*)\])?\n([\s\S]*?)^:::$/gm, (_, kind: string, title: string | undefined, text: string) => {
      const label = title || { note: "Note", tip: "Tip", caution: "Caution", danger: "Danger" }[kind];
      return [`**${label}**`, "", ...text.trim().split("\n")].map((line) => (line ? `> ${line}` : ">")).join("\n");
    })
    // Keys, as macOS prints them.
    .replace(/<kbd class="key">([^<]*)<\/kbd>/g, "$1")
    // Pictures of the app become their descriptions.
    .replace(/!\[([^\]]*)\]\([^)]*\)/g, (_, alt: string) => (alt ? `*Screenshot: ${alt}*` : ""))
    // Links between pages, in full.
    .replace(/\]\((\/[^)\s]*)\)/g, (_, path: string) => `](${site.url}${path})`)
    .replace(/\n{3,}/g, "\n\n")
    .trim();
  return `# ${entry.data.title}\n\n> ${entry.data.description}\n\n${body}\n`;
}
