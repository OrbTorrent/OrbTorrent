#!/usr/bin/env node
// Compares what each official extension can do between two commits, and
// prints the differences as markdown for a pull request comment. Prints
// nothing when no extension's hooks or permissions changed.
//
// It only reads package.json files out of git and never runs the code it
// compares, so CI can run it on a pull request from a fork with a token that
// can comment (.github/workflows/extension-permissions.yml).
//
// Usage: node scripts/extension-permissions.mjs <base ref> [<head ref>]
// Without a head ref, it compares the files as they are now.
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(import.meta.dirname, "..");

const list = (value) => (Array.isArray(value) ? value : value === undefined || value === null ? [] : [value]);

/** What users are told the extension can do, word for word as OrbTorrent
 *  says it (`ExtensionManifest.abilities`). */
export function abilities(manifest) {
  if (!manifest) return [];
  const lines = ["See the names and sizes of the files in your downloads"];
  if (list(manifest.hooks).some((hook) => hook?.event === "beforeStart")) lines.push("Hold a download before it starts, until you decide");
  const files = list(manifest.permissions?.files);
  if (files.includes("contents")) lines.push("Read the contents of your downloads");
  if (files.includes("add")) lines.push("Add files, such as subtitles, next to your downloads");
  for (const host of list(manifest.permissions?.network)) lines.push(`Connect to ${String(host).toLowerCase()}`);
  return lines;
}

const hooks = (manifest) => list(manifest?.hooks).map((hook) => `${hook?.name} (${hook?.event})`);

/** One extension's changes as a markdown section, or nothing if none.
 *  A manifest is undefined when there's none, and null when it isn't JSON. */
export function differences(name, before, now) {
  if (now === null) {
    return before === null ? undefined : `### ${before?.title ?? name}\n- ⚠️ Its package.json isn't valid JSON, so what it can do couldn't be compared.`;
  }
  const added = abilities(now).filter((line) => !abilities(before).includes(line));
  const removed = abilities(before).filter((line) => !abilities(now).includes(line));
  const newHooks = hooks(now).filter((hook) => !hooks(before).includes(hook));
  const goneHooks = hooks(before).filter((hook) => !hooks(now).includes(hook));
  if (!added.length && !removed.length && !newHooks.length && !goneHooks.length) return undefined;
  const status = !before ? " (new extension)" : !now ? " (removed)" : "";
  const lines = [`### ${now?.title ?? before?.title ?? name}${status}`];
  for (const line of added) lines.push(`- ➕ **Can now:** ${line}`);
  for (const line of removed) lines.push(`- ➖ No longer: ${line}`);
  for (const hook of newHooks) lines.push(`- ➕ **New hook:** ${hook}`);
  for (const hook of goneHooks) lines.push(`- ➖ Removed hook: ${hook}`);
  return lines.join("\n");
}

function git(...args) {
  return execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] });
}

/** The folders in extensions/ at a commit, or now. */
function names(ref) {
  if (!ref) return existsSync(join(root, "extensions")) ? readdirSync(join(root, "extensions")) : [];
  try {
    return git("ls-tree", "-d", "--name-only", `${ref}:extensions`).split("\n").filter(Boolean);
  } catch {
    return [];
  }
}

/** An extension's package.json at a commit, or now. */
function manifest(ref, name) {
  const path = `extensions/${name}/package.json`;
  let text;
  try {
    text = ref ? git("show", `${ref}:${path}`) : readFileSync(join(root, path), "utf8");
  } catch {
    return undefined;
  }
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [base = "origin/main", head] = process.argv.slice(2);
  const sections = [...new Set([...names(base), ...names(head)])]
    .sort()
    .map((name) => differences(name, manifest(base, name), manifest(head, name)))
    .filter(Boolean);
  if (sections.length > 0) {
    console.log([
      "## Extension permissions changed",
      "",
      "Users are asked to allow what an extension can do, so check these first.",
      "",
      sections.join("\n\n"),
    ].join("\n"));
  }
}
