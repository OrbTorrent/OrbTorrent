#!/usr/bin/env node
// Writes docs/extensions/llms.txt and llms-full.txt from the extension docs,
// and copies AGENTS.md into the Agent Skill. With --check, fails if any of
// them is out of date instead.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const docs = join(root, "docs", "extensions");
const pages = {
  "README.md": "What extensions are, and the official ones.",
  "getting-started.md": "Make an extension from a template, and the loop: orb test, build, lint, dev and run.",
  "hooks.md": "When beforeStart and afterFinish hooks run, what they receive and return, and their limits.",
  "api.md": "fetch, files, progress, storage, getPreferenceValues, environment and sleep, and the web APIs available.",
  "manifest.md": "Every field of package.json: hooks, permissions and preferences.",
  "testing.md": "JSON tests that run without OrbTorrent: mocks, expectations and the virtual clock.",
  "sharing.md": ".orbext files, and changing the official extensions.",
  "security.md": "The sandboxed extension host, network rules, secrets, and the development socket.",
};
const base = "https://github.com/sanjevirau/OrbTorrent/blob/main/docs/extensions";

const read = (name) => readFileSync(join(docs, name), "utf8").trim();
const title = (text) => text.match(/^# (.+)$/m)?.[1] ?? "";

const index = [
  "# OrbTorrent Extensions",
  "",
  "> Extensions hook into moments in a download's life in OrbTorrent, a BitTorrent app for macOS: before it starts (and can hold it) or after it finishes. They're TypeScript, run in a sandboxed JavaScriptCore host, and reach the network, files and storage only through @orbtorrent/api.",
  "",
  "## Docs",
  "",
  ...Object.entries(pages).map(([page, about]) => `- [${title(read(page))}](${base}/${page}): ${about}`),
  "",
  "## For coding agents",
  "",
  `- [AGENTS.md](https://github.com/sanjevirau/OrbTorrent/blob/main/sdk/templates/_shared/AGENTS.md): the whole API, the rules and the loop, in one file. Every extension made with \`orb create\` has it.`,
  `- [Agent Skill](https://github.com/sanjevirau/OrbTorrent/tree/main/skills/build-orbtorrent-extension): for Claude Code, Codex, Cursor and other agents that use the Agent Skills format.`,
  "",
].join("\n");
const full = Object.keys(pages).map(read).join("\n\n---\n\n") + "\n";
const agents = readFileSync(join(root, "sdk", "templates", "_shared", "AGENTS.md"), "utf8").replaceAll("{{title}}", "Your extension");

const outputs = {
  [join(docs, "llms.txt")]: index,
  [join(docs, "llms-full.txt")]: full,
  [join(root, "skills", "build-orbtorrent-extension", "references", "AGENTS.md")]: agents,
};
const check = process.argv.includes("--check");
let stale = false;
for (const [path, text] of Object.entries(outputs)) {
  let current = "";
  try { current = readFileSync(path, "utf8"); } catch {}
  if (current === text) continue;
  if (check) {
    console.error(`${path.slice(root.length + 1)} is out of date. Run: node scripts/extension-docs.mjs`);
    stale = true;
  } else {
    writeFileSync(path, text);
    console.log(`Wrote ${path.slice(root.length + 1)}`);
  }
}
process.exitCode = stale ? 1 : 0;
