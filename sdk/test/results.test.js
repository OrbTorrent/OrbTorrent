import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { asShown } from "../dist/cli/harness.js";

// Results as OrbTorrent shows them (Extensions.swift), and what `orb test`
// gives hooks that run once a download finishes and once its checks are done.

const files = { 0: { path: "Pack/film.mkv" }, 1: { path: "Pack/setup.exe" } };

test("a result is no better than its worst file, and says so", () => {
  const shown = asShown({ status: "passed", summary: "Fine", files: [{ file: 0, status: "passed" }, { file: { index: 1 }, status: "failed", summary: "Bad" }] }, files);
  assert.equal(shown.result.status, "failed");
  assert.deepEqual(shown.result.files.map((file) => [file.path, file.status]), [["Pack/setup.exe", "failed"], ["Pack/film.mkv", "passed"]]);
  assert.equal(shown.warning, "Its result said “passed”, but setup.exe is “failed”, so it shows as failed.");
});

test("a file named twice keeps its worst result", () => {
  const shown = asShown({ status: "failed", summary: "Bad", files: [{ file: 1, status: "warning" }, { file: 1, status: "failed" }, { file: 1, status: "passed" }] }, files);
  assert.deepEqual(shown.result.files.map((file) => file.status), ["failed"]);
  assert.equal(shown.warning, undefined);
});

test("results OrbTorrent can't show are refused with what to do", () => {
  assert.equal(asShown({ status: "fine", summary: "x" }, files).problem, "It returned something that isn't a result: return { status, summary }.");
  assert.equal(asShown({ status: "passed", summary: "x", files: {} }, files).problem,
    "Its result's “files” isn't a list. Return files: [{ file, status, summary }].");
  assert.equal(asShown({ status: "passed", summary: "x", files: [{ file: 7, status: "passed" }] }, files).problem,
    "Its result's “files” names a file that isn't part of this download. Pass a file from download.files, or its index.");
  assert.equal(asShown({ status: "passed", summary: "x", files: [{ file: 1, status: "skipped" }] }, files).problem,
    "Its result gives setup.exe a status that isn't “passed”, “warning” or “failed”.");
});

const orb = join(import.meta.dirname, "..", "bin", "orb.js");

test("orb test gives new files, other checks and held downloads, and checks file results", { timeout: 60_000 }, () => {
  // Inside the repository, so the build finds @orbtorrent/api.
  const folder = mkdtempSync(join(import.meta.dirname, ".results-"));
  try {
    const write = (path, contents) => {
      mkdirSync(join(folder, path, ".."), { recursive: true });
      writeFileSync(join(folder, path), typeof contents === "string" ? contents : JSON.stringify(contents));
    };
    write("package.json", {
      name: "reporter", title: "Reporter", description: "Reports.", author: "you",
      hooks: [{ name: "report", event: "afterChecks" }, { name: "scan", event: "afterFinish" }],
      permissions: { files: "contents" },
    });
    write("src/report.js", `
      import { files } from "@orbtorrent/api";
      export default async function report(download) {
        const fresh = download.files.filter((file) => file.isNew).length;
        const found = (download.checks ?? []).map((check) =>
          check.extension.title + ": " + check.status + " " + (check.files ?? []).map((file) => file.path + "#" + file.index).join(","));
        let read = "read";
        try { await files.sha256(download.files[0]); } catch (error) { read = error.message; }
        return { status: "passed", summary: fresh + " new; held " + download.isHeld + "; " + found.join("; ") + "; " + read };
      }`);
    write("src/scan.js", `
      export default function scan(download) {
        return { status: "passed", summary: "Fine", files: [{ file: download.files[1], status: "failed", summary: "Bad" }, { file: 0, status: "passed" }] };
      }`);
    const download = { name: "Pack", files: [{ path: "Pack/film.mkv", sha256: "a", isNew: false }, { path: "Pack/setup.exe", sha256: "b" }] };
    write("tests/finished.json", {
      hook: "report",
      download: { ...download, checks: [{ extension: { name: "virustotal", title: "VirusTotal Scan" }, status: "failed", summary: "Bad", files: [{ path: "Pack/setup.exe", status: "failed" }] }] },
      expect: { status: "passed", summaryIncludes: "1 new; held false; VirusTotal Scan: failed Pack/setup.exe#1; read" },
    });
    write("tests/held.json", {
      hook: "report",
      download: { ...download, held: true },
      expect: { summaryIncludes: "0 new; held true; ; File 0 isn't available" },
    });
    write("tests/raised.json", { hook: "scan", download, expect: { status: "failed", files: { "Pack/setup.exe": "failed", "*.mkv": "passed" } } });
    write("tests/wrong.json", { hook: "scan", download, expect: { files: { "Pack/film.mkv": "failed", "*.txt": "warning" } } });

    const result = spawnSync(process.execPath, [orb, "test", "--json"], { cwd: folder, encoding: "utf8" });
    const output = JSON.parse(result.stdout);
    const failures = Object.fromEntries(output.tests.map((report) => [report.name, report.failures]));
    assert.deepEqual(failures.finished, []);
    assert.deepEqual(failures.held, []);
    assert.deepEqual(failures.raised, []);
    assert.deepEqual(failures.wrong, [
      "expected Pack/film.mkv to be “failed”, got “passed”",
      "expected *.txt to be “warning”, but the result says nothing about it",
    ]);
    assert.ok(output.tests.find((report) => report.name === "raised").logs.some((log) => log.level === "warn" && log.message.includes("so it shows as failed")));
  } finally {
    rmSync(folder, { recursive: true, force: true });
  }
});
