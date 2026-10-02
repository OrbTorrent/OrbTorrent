#!/usr/bin/env node
// Copies the template's AGENTS.md into the Agent Skill, so the skill and new
// extensions tell coding agents the same thing. With --check, fails if the
// skill's copy is out of date instead.
//
// The extension docs themselves, with their llms.txt and llms-full.txt, are
// built with the website, from website/src/content/docs/docs/extensions.
import { readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const agents = readFileSync(join(root, "sdk", "templates", "_shared", "AGENTS.md"), "utf8").replaceAll("{{title}}", "Your extension");

const outputs = {
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
