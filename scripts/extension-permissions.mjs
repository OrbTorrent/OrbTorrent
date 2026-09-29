#!/usr/bin/env node
// Compares what each official extension can do with a base commit, and prints
// the differences as markdown for a pull request comment. Prints nothing when
// no extension's hooks or permissions changed.
//
// Usage: node scripts/extension-permissions.mjs <base ref>
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = join(import.meta.dirname, "..");
const base = process.argv[2] ?? "origin/main";

/** What users are told the extension can do, as OrbTorrent words it. */
function abilities(manifest) {
  if (!manifest) return [];
  const lines = ["See the names and sizes of the files in your downloads"];
  if ((manifest.hooks ?? []).some((hook) => hook.event === "beforeStart")) lines.push("Hold a download before it starts, until you decide");
  if (manifest.permissions?.files === "contents") lines.push("Read the contents of your downloads");
  for (const host of manifest.permissions?.network ?? []) lines.push(`Connect to ${String(host).toLowerCase()}`);
  return lines;
}

const hooks = (manifest) => (manifest?.hooks ?? []).map((hook) => `${hook.name} (${hook.event})`);

function atBase(path) {
  try {
    return JSON.parse(execFileSync("git", ["show", `${base}:${path}`], { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }));
  } catch {
    return undefined;
  }
}

const sections = [];
for (const name of readdirSync(join(root, "extensions")).sort()) {
  const path = `extensions/${name}/package.json`;
  if (!existsSync(join(root, path))) continue;
  const now = JSON.parse(readFileSync(join(root, path), "utf8"));
  const before = atBase(path);
  const added = abilities(now).filter((line) => !abilities(before).includes(line));
  const removed = abilities(before).filter((line) => !abilities(now).includes(line));
  const newHooks = hooks(now).filter((hook) => !hooks(before).includes(hook));
  const goneHooks = hooks(before).filter((hook) => !hooks(now).includes(hook));
  if (!added.length && !removed.length && !newHooks.length && !goneHooks.length) continue;
  const lines = [`### ${now.title ?? name}${before ? "" : " (new extension)"}`];
  for (const line of added) lines.push(`- ➕ **Can now:** ${line}`);
  for (const line of removed) lines.push(`- ➖ No longer: ${line}`);
  for (const hook of newHooks) lines.push(`- ➕ **New hook:** ${hook}`);
  for (const hook of goneHooks) lines.push(`- ➖ Removed hook: ${hook}`);
  sections.push(lines.join("\n"));
}

if (sections.length > 0) {
  console.log([
    "## Extension permissions changed",
    "",
    "Users are asked to allow what an extension can do, so check these first.",
    "",
    sections.join("\n\n"),
  ].join("\n"));
}
