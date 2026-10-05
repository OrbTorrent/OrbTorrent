import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import net from "node:net";
import { join } from "node:path";
import { test } from "node:test";
import { promisify } from "node:util";
import { apiSupports } from "../dist/cli/doctor.js";

const orb = join(import.meta.dirname, "..", "bin", "orb.js");

/** Runs orb as if `home` were the home folder, without blocking the fake app's socket. */
async function run(args, { cwd, home }) {
  try {
    const { stdout } = await promisify(execFile)(process.execPath, [orb, ...args],
      { cwd, env: { ...process.env, HOME: home, ORB_APP: "" }, encoding: "utf8" });
    return { status: 0, stdout };
  } catch (error) {
    return { status: error.code, stdout: error.stdout, stderr: error.stderr };
  }
}

const hello = { type: "hello", app: "OrbTorrent", version: "1.0", api: "1.2.0" };

/**
 * A stand-in for OrbTorrent's development socket, answering each request
 * type from `answers`. It lives under /tmp because a socket's path can only
 * be about 100 characters long.
 */
async function fakeApp(answers) {
  const home = mkdtempSync("/tmp/orb-");
  const folder = join(home, "Library", "Application Support", "OrbTorrent");
  mkdirSync(folder, { recursive: true });
  const received = [];
  const server = net.createServer((socket) => {
    let buffer = "";
    socket.setEncoding("utf8");
    socket.on("data", (chunk) => {
      buffer += chunk;
      let newline;
      while ((newline = buffer.indexOf("\n")) >= 0) {
        const message = JSON.parse(buffer.slice(0, newline));
        buffer = buffer.slice(newline + 1);
        received.push(message);
        const reply = answers[message.type] ?? { type: "error", message: "OrbTorrent doesn't know that request." };
        socket.write(JSON.stringify(reply) + "\n");
      }
    });
  });
  await new Promise((resolve) => server.listen(join(folder, "dev.sock"), resolve));
  return {
    home,
    received,
    close() {
      server.close();
      rmSync(home, { recursive: true, force: true });
    },
  };
}

/** A built extension's folder, as far as `orb doctor` looks. */
function makeExtension(home) {
  const folder = join(home, "size-guard");
  mkdirSync(join(folder, "dist"), { recursive: true });
  const manifest = { name: "size-guard", title: "Size Guard", hooks: [{ name: "check", title: "Check", event: "beforeStart" }] };
  writeFileSync(join(folder, "package.json"), JSON.stringify(manifest));
  writeFileSync(join(folder, "dist", "package.json"), JSON.stringify(manifest));
  return folder;
}

const byName = (checks) => Object.fromEntries(checks.map((check) => [check.name, check]));

test("an extension runs in an OrbTorrent with the same major API and at least its minor", () => {
  assert.equal(apiSupports("1.0", "1.0.1"), true);
  assert.equal(apiSupports("1.1", "1.0.0"), true);
  assert.equal(apiSupports("1.0", "1.1.0"), false);
  assert.equal(apiSupports("2.0", "1.0.0"), false);
});

test("orb downloads lists OrbTorrent's downloads", async () => {
  const downloads = [{ id: "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c", name: "Big Buck Bunny", size: 276445467, progress: 1, finished: true }];
  const app = await fakeApp({ hello, downloads: { type: "downloads", downloads } });
  try {
    const result = await run(["downloads", "--json"], { cwd: app.home, home: app.home });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    assert.deepEqual(JSON.parse(result.stdout), { ok: true, downloads });
  } finally {
    app.close();
  }
});

test("orb doctor says an extension is allowed and installed", async () => {
  const app = await fakeApp({
    hello,
    status: { type: "status", api: "1.2.0", allowed: true, active: { source: "installed", version: "1.0.0", on: true }, installed: { version: "1.0.0" } },
  });
  try {
    const folder = makeExtension(app.home);
    const result = await run(["doctor", "--json"], { cwd: folder, home: app.home });
    const report = JSON.parse(result.stdout);
    const checks = byName(report.checks);
    assert.equal(result.status, 0, result.stdout);
    assert.equal(report.ok, true);
    assert.equal(checks.app.ok, true);
    assert.equal(checks.api.ok, true);
    assert.equal(checks.allowed.ok, true);
    assert.match(checks.installed.message, /, version 1\.0\.0, on\./);
    const status = app.received.find((message) => message.type === "status");
    assert.equal(status.name, "size-guard");
    assert.match(status.path, /size-guard\/dist$/);
  } finally {
    app.close();
  }
});

test("orb doctor says when OrbTorrent is too old for the extension", async () => {
  const app = await fakeApp({ hello: { ...hello, api: "0.9.0" }, status: { type: "status", api: "0.9.0" } });
  try {
    const result = await run(["doctor", "--json"], { cwd: makeExtension(app.home), home: app.home });
    const checks = byName(JSON.parse(result.stdout).checks);
    assert.equal(result.status, 1);
    assert.equal(checks.api.ok, false);
    assert.match(checks.api.fix, /Check for Updates/);
  } finally {
    app.close();
  }
});

test("orb doctor says what the user must do when OrbTorrent can't be reached", async () => {
  const home = mkdtempSync("/tmp/orb-");
  try {
    const result = await run(["doctor", "--json"], { cwd: makeExtension(home), home });
    const report = JSON.parse(result.stdout);
    const checks = byName(report.checks);
    assert.equal(result.status, 1);
    assert.equal(report.ok, false);
    assert.equal(checks.app.ok, false);
    // Open without the switch, closed, or not installed: each says what to do.
    assert.match(checks.app.fix, /Allow development extensions|orbtorrent\.com/);
  } finally {
    rmSync(home, { recursive: true, force: true });
  }
});

/** A real extension, from the before-start template, to package. */
async function makeRealExtension(home) {
  const made = await run(["create", "size-guard", "--json"], { cwd: home, home });
  assert.equal(made.status, 0, made.stdout + made.stderr);
  const folder = join(home, "size-guard");
  await promisify(execFile)("npm", ["install", "--no-audit", "--no-fund", "--offline"], { cwd: folder });
  return folder;
}

// Packaging an extension uses macOS's ditto, so these run on a Mac only.
const onMac = { timeout: 120_000, skip: process.platform !== "darwin" && "packaging needs macOS" };

test("orb install waits for the user to confirm it in OrbTorrent", onMac, async () => {
  const app = await fakeApp({ hello, install: { type: "installed", name: "size-guard" } });
  try {
    const folder = await makeRealExtension(app.home);
    const result = await run(["install", "--json"], { cwd: folder, home: app.home });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const report = JSON.parse(result.stdout);
    assert.equal(report.installed, true);
    const install = app.received.find((message) => message.type === "install");
    assert.match(install.path, /size-guard\.orbext$/);
  } finally {
    app.close();
  }
});

test("orb install says when the user chose not to install it", onMac, async () => {
  const app = await fakeApp({ hello, install: { type: "error", message: "The user chose not to install it." } });
  try {
    const folder = await makeRealExtension(app.home);
    const result = await run(["install", "--json"], { cwd: folder, home: app.home });
    assert.equal(result.status, 1);
    assert.deepEqual(JSON.parse(result.stdout), { ok: false, error: "The user chose not to install it.", details: [] });
  } finally {
    app.close();
  }
});
