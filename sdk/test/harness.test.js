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
