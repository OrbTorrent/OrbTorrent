import assert from "node:assert/strict";
import { test } from "node:test";
import { runInHarness } from "../dist/cli/harness.js";
import { validateManifest } from "../dist/cli/manifest.js";

const manifest = (permissions = {}) => validateManifest({
  name: "x", title: "T", description: "D", author: "A", hooks: [{ name: "scan", event: "afterFinish" }], permissions,
});
const options = (overrides = {}) => ({
  manifest: manifest(), entryPoint: { type: "hook", name: "scan", event: "afterFinish" }, preferences: {},
  fetchMocks: [], files: {}, storage: {}, timeout: 5000, ...overrides,
});
const hook = (body) => `var __orbExtension = { default: async (download) => { ${body} } };`;

test("a request to an undeclared host is refused with how to allow it", async () => {
  const run = await runInHarness(hook(`return await __orb.call("fetch", { url: "https://api.example.com/x" });`), [{}], options());
  assert.equal(run.outcome.ok, false);
  assert.equal(run.outcome.message, `Request to api.example.com was refused. Add "api.example.com" to permissions.network in package.json.`);
});

test("mocks answer in turn, with * matching any text", async () => {
  const run = await runInHarness(hook(`
    const a = await __orb.call("fetch", { url: "https://api.example.com/files/1" });
    const b = await __orb.call("fetch", { url: "https://api.example.com/files/2" });
    return [a.status, b.status];`), [{}], options({
    manifest: manifest({ network: ["api.example.com"] }),
    fetchMocks: [{ url: "https://api.example.com/files/*", status: 429, times: 1 }, { url: "https://api.example.com/files/*", status: 200 }],
  }));
  assert.deepEqual(run.outcome, { ok: true, value: [429, 200] });
  assert.equal(run.fetched.length, 2);
});

test("time runs on a virtual clock", async () => {
  const started = Date.now();
  const run = await runInHarness(hook(`
    const before = Date.now();
    await new Promise((resolve) => setTimeout(resolve, 60000));
    return Date.now() - before;`), [{}], options());
  assert.equal(run.outcome.ok, true);
  assert.ok(run.outcome.value >= 60000);
  assert.ok(Date.now() - started < 2000);
});

test("files can't be read before a download starts", async () => {
  const run = await runInHarness(hook(`return await __orb.call("files.sha256", { file: 0 });`), [{}], options({
    manifest: manifest({ files: "contents" }), entryPoint: { type: "hook", name: "scan", event: "beforeStart" }, files: { 0: { sha256: "a" } },
  }));
  assert.equal(run.outcome.ok, false);
  assert.match(run.outcome.message, /isn't downloaded yet/);
});

// files.save, with the same rules and words as OrbTorrent (ExtensionFileAdder.swift).
const film = { 0: { path: "Film (2024)/Film.2024.1080p.mkv", wanted: true }, 1: { path: "Film (2024)/Sample/sample.mkv", wanted: false } };
const save = (args) => hook(`return await __orb.call("files.save", ${JSON.stringify(args)});`);

test("a file is added next to the download's, named after it", async () => {
  const run = await runInHarness(save({ file: 0, suffix: ".en.srt", contents: { text: "1\n00:00:01,000 --> 00:00:02,000\nHello\n" } }), [{}],
    options({ manifest: manifest({ files: "add" }), files: film }));
  assert.deepEqual(run.outcome, { ok: true, value: { path: "Film (2024)/Film.2024.1080p.en.srt", size: 38 } });
  assert.deepEqual(run.saved.map((saved) => saved.path), ["Film (2024)/Film.2024.1080p.en.srt"]);
  assert.match(run.saved[0].text, /Hello/);
});

test("adding files needs its permission", async () => {
  const run = await runInHarness(save({ file: 0, suffix: ".en.srt", contents: { text: "x" } }), [{}], options({ manifest: manifest({ files: "contents" }), files: film }));
  assert.equal(run.outcome.message, `Adding files isn't allowed. Add "files": "add" to permissions in package.json, or ["contents", "add"] to read files too.`);
});

test("only subtitles, text, images and checksums can be added", async () => {
  const run = await runInHarness(save({ file: 0, suffix: ".command", contents: { text: "x" } }), [{}], options({ manifest: manifest({ files: "add" }), files: film }));
  assert.match(run.outcome.message, /^Extensions can't add \.command files, only subtitles, text, images and checksums: \.srt, /);
});

test("a suffix can't lead to another folder", async () => {
  for (const suffix of ["/../../.zshrc.txt", "en.srt", ".en\\x.srt", ".srt:x", ".", ""]) {
    const run = await runInHarness(save({ file: 0, suffix, contents: { text: "x" } }), [{}], options({ manifest: manifest({ files: "add" }), files: film }));
    assert.match(run.outcome.message, /can't be added to a file's name/, suffix);
  }
});

test("a file that's already there is never replaced", async () => {
  const there = await runInHarness(save({ file: 0, suffix: ".en.srt", contents: { text: "x" } }), [{}],
    options({ manifest: manifest({ files: "add" }), files: film, alsoOnDisk: ["Film (2024)/Film.2024.1080p.en.srt"] }));
  assert.equal(there.outcome.message, "“Film.2024.1080p.en.srt” already exists. An extension can't replace a file it didn't add.");
  const twice = await runInHarness(hook(`
    await __orb.call("files.save", { file: 0, suffix: ".en.srt", contents: { text: "a" } });
    return await __orb.call("files.save", { file: 0, suffix: ".en.srt", contents: { text: "b" } });`), [{}],
    options({ manifest: manifest({ files: "add" }), files: film }));
  assert.match(twice.outcome.message, /already exists/);
});

test("files are only added once a download finishes, next to the files it downloaded", async () => {
  const before = await runInHarness(save({ file: 0, suffix: ".en.srt", contents: { text: "x" } }), [{}],
    options({ manifest: manifest({ files: "add" }), files: film, entryPoint: { type: "hook", name: "scan", event: "beforeStart" } }));
  assert.match(before.outcome.message, /isn't downloaded yet/);
  const skipped = await runInHarness(save({ file: 1, suffix: ".en.srt", contents: { text: "x" } }), [{}], options({ manifest: manifest({ files: "add" }), files: film }));
  assert.match(skipped.outcome.message, /File 1 isn't available/);
});

test("a file can be at most 10 MB", async () => {
  const run = await runInHarness(hook(`return await __orb.call("files.save", { file: 0, suffix: ".txt", contents: { text: "x".repeat((10 << 20) + 1) } });`), [{}],
    options({ manifest: manifest({ files: "add" }), files: film }));
  assert.equal(run.outcome.message, "“Film.2024.1080p.txt” is larger than 10 MB, the most an extension can add in one file.");
});

test("storage is limited to 1 MB", async () => {
  const run = await runInHarness(hook(`await __orb.call("storage.set", { key: "big", value: "x".repeat(1 << 20) });`), [{}], options());
  assert.equal(run.outcome.ok, false);
  assert.match(run.outcome.message, /Storage is full/);
});

test("a hook that never finishes times out", async () => {
  const run = await runInHarness(hook(`return new Promise(() => {});`), [{}], options({ timeout: 200 }));
  assert.equal(run.outcome.ok, false);
  assert.equal(run.outcome.timedOut, true);
});
