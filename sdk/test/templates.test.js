import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const orb = join(import.meta.dirname, "..", "bin", "orb.js");
const run = (args, cwd) => spawnSync(process.execPath, [orb, ...args], { cwd, encoding: "utf8" });

for (const template of ["before-start", "after-finish"]) {
  test(`an extension made from the ${template} template passes its tests, builds and lints`, { timeout: 120_000 }, () => {
    const folder = mkdtempSync(join(tmpdir(), "orb-template-"));
    try {
      const created = run(["create", "made-by-test", "--template", template, "--json"], folder);
      assert.equal(created.status, 0, created.stdout + created.stderr);
      const extension = join(folder, "made-by-test");
      const install = spawnSync("npm", ["install", "--no-audit", "--no-fund", "--offline"], { cwd: extension, encoding: "utf8" });
      assert.equal(install.status, 0, install.stdout + install.stderr);
      for (const command of [["test", "--json"], ["build", "--json"], ["lint", "--json"]]) {
        const result = run(command, extension);
        assert.equal(result.status, 0, `orb ${command[0]}: ${result.stdout}${result.stderr}`);
        assert.equal(JSON.parse(result.stdout).ok, true);
      }
    } finally {
      rmSync(folder, { recursive: true, force: true });
    }
  });
}
