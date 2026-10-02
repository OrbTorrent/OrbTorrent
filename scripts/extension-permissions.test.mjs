// Tests for extension-permissions.mjs: node --test scripts/
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { abilities, differences } from "./extension-permissions.mjs";

const root = join(import.meta.dirname, "..");

test("says what an extension can do word for word as the app does", () => {
  const swift = readFileSync(join(root, "OrbTorrent/Extensions/ExtensionManifest.swift"), "utf8");
  const lines = abilities({
    hooks: [{ name: "check", event: "beforeStart" }],
    permissions: { files: ["contents", "add"], network: [] },
  });
  assert.equal(lines.length, 4);
  for (const line of lines) assert.ok(swift.includes(`"${line}"`), `ExtensionManifest.swift doesn't say “${line}”`);
});

test("reads every form of the files permission", () => {
  const can = (files) => abilities({ permissions: { files } }).slice(1);
  assert.deepEqual(can("contents"), ["Read the contents of your downloads"]);
  assert.deepEqual(can("add"), ["Add files, such as subtitles, next to your downloads"]);
  assert.deepEqual(can(["contents", "add"]), ["Read the contents of your downloads", "Add files, such as subtitles, next to your downloads"]);
  assert.deepEqual(can(undefined), []);
});

test("shows only what changed", () => {
  const before = { title: "VirusTotal Scan", permissions: { files: "contents", network: ["www.virustotal.com"] } };
  const now = { title: "VirusTotal Scan", permissions: { files: ["contents", "add"], network: ["WWW.virustotal.com", "example.com"] } };
  assert.equal(differences("virustotal", before, now), [
    "### VirusTotal Scan",
    "- ➕ **Can now:** Add files, such as subtitles, next to your downloads",
    "- ➕ **Can now:** Connect to example.com",
  ].join("\n"));
  assert.equal(differences("virustotal", before, before), undefined);
});

test("compares two commits without running either", () => {
  const repo = mkdtempSync(join(tmpdir(), "extension-permissions-"));
  try {
    const git = (...args) => execFileSync("git", ["-c", "user.name=Test", "-c", "user.email=test@example.com", ...args], { cwd: repo, encoding: "utf8" });
    const write = (name, manifest) => {
      mkdirSync(join(repo, "extensions", name), { recursive: true });
      writeFileSync(join(repo, "extensions", name, "package.json"), typeof manifest === "string" ? manifest : JSON.stringify(manifest));
    };
    mkdirSync(join(repo, "scripts"));
    copyFileSync(join(root, "scripts/extension-permissions.mjs"), join(repo, "scripts/extension-permissions.mjs"));
    git("init", "--quiet");
    write("same", { title: "Same", permissions: { files: "contents" } });
    write("scan", { title: "Scan", hooks: [{ name: "scan", event: "afterFinish" }], permissions: { files: "contents" } });
    write("gone", { title: "Gone", permissions: { network: ["example.com"] } });
    git("add", "-A");
    git("commit", "--quiet", "-m", "Base");
    const base = git("rev-parse", "HEAD").trim();
    write("scan", { title: "Scan", hooks: [{ name: "scan", event: "afterFinish" }], permissions: { files: ["contents", "add"] } });
    write("subtitles", { title: "Subtitles", hooks: [{ name: "find", event: "afterFinish" }], permissions: { files: "add" } });
    write("broken", "{ not json");
    rmSync(join(repo, "extensions", "gone"), { recursive: true });
    git("add", "-A");
    git("commit", "--quiet", "-m", "Head");

    const run = (...refs) => execFileSync(process.execPath, ["scripts/extension-permissions.mjs", ...refs], { cwd: repo, encoding: "utf8" });
    const output = run(base, "HEAD");
    assert.match(output, /^## Extension permissions changed/);
    assert.match(output, /### Scan\n- ➕ \*\*Can now:\*\* Add files, such as subtitles, next to your downloads\n\n/);
    assert.match(output, /### Subtitles \(new extension\)\n.*\n- ➕ \*\*Can now:\*\* Add files, such as subtitles, next to your downloads\n- ➕ \*\*New hook:\*\* find \(afterFinish\)/);
    assert.match(output, /### Gone \(removed\)\n.*\n- ➖ No longer: Connect to example.com/);
    assert.match(output, /### broken\n- ⚠️ Its package.json isn't valid JSON/);
    assert.doesNotMatch(output, /### Same/);
    // Without a head ref, it compares the files as they are now.
    assert.equal(run(base), output);
    assert.equal(run("HEAD", "HEAD"), "");
  } finally {
    rmSync(repo, { recursive: true, force: true });
  }
});
