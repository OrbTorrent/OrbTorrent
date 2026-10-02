import assert from "node:assert/strict";
import { join } from "node:path";
import { test } from "node:test";
import * as esbuild from "esbuild";
import { runInHarness } from "../dist/cli/harness.js";
import { validateManifest } from "../dist/cli/manifest.js";

// The API itself, bundled into a hook the way `orb build` does, and run in
// the harness: what crosses to OrbTorrent and back, such as bytes in Base64.
async function bundle(body) {
  const result = await esbuild.build({
    stdin: { contents: `import { fetch, files } from ${JSON.stringify(join(import.meta.dirname, "..", "dist", "index.js"))};\nexport default async function (download) { ${body} }`, resolveDir: import.meta.dirname, loader: "js" },
    bundle: true, format: "iife", globalName: "__orbExtension", platform: "neutral", write: false, logLevel: "silent",
  });
  return result.outputFiles[0].text;
}

const manifest = validateManifest({
  name: "x", title: "T", description: "D", author: "A", hooks: [{ name: "scan", event: "afterFinish" }],
  permissions: { files: ["contents", "add"], network: ["images.example.com"] },
});
const options = (overrides = {}) => ({
  manifest, entryPoint: { type: "hook", name: "scan", event: "afterFinish" }, preferences: {}, fetchMocks: [],
  files: { 0: { path: "Album/01 Song.flac" } }, storage: {}, timeout: 5000, ...overrides,
});

// Every byte value, which isn't valid UTF-8, so it travels in Base64.
const everyByte = Buffer.from(Array.from({ length: 256 }, (_, index) => index));

test("bytes from a response are saved intact", async () => {
  const script = await bundle(`
    const response = await fetch("https://images.example.com/cover.jpg");
    const bytes = await response.bytes();
    const saved = await files.save(download.files[0], "-cover.jpg", bytes);
    return { length: bytes.length, buffer: (await response.arrayBuffer()).byteLength, saved };`);
  const run = await runInHarness(script, [{ files: [{ index: 0, path: "Album/01 Song.flac", size: 1, wanted: true }] }],
    options({ fetchMocks: [{ url: "https://images.example.com/cover.jpg", base64: everyByte.toString("base64") }] }));
  assert.deepEqual(run.outcome, { ok: true, value: { length: 256, buffer: 256, saved: { path: "Album/01 Song-cover.jpg", size: 256 } } });
  assert.equal(run.saved[0].size, 256);
});

test("text responses still read as text, and as bytes", async () => {
  const script = await bundle(`
    const response = await fetch("https://images.example.com/lyrics");
    return { text: await response.text(), bytes: Array.from(await response.bytes()) };`);
  const run = await runInHarness(script, [{}], options({ fetchMocks: [{ url: "https://images.example.com/lyrics", text: "Café" }] }));
  assert.deepEqual(run.outcome, { ok: true, value: { text: "Café", bytes: [67, 97, 102, 195, 169] } });
});

test("text saved from a hook is UTF-8", async () => {
  const script = await bundle(`return await files.save(0, ".lrc", "[00:01.00] Café ☕");`);
  const run = await runInHarness(script, [{}], options());
  assert.deepEqual(run.outcome.value, { path: "Album/01 Song.lrc", size: 20 });
  assert.equal(run.saved[0].text, "[00:01.00] Café ☕");
});
