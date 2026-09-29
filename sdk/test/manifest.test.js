import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { InvalidManifest, builtManifest, defaultPreferences, environmentDeclarations, validateManifest } from "../dist/cli/manifest.js";

const fixtures = join(import.meta.dirname, "fixtures", "manifests");

// The same fixtures are checked against OrbTorrent's own validation
// (OrbTorrentTests/ExtensionManifestTests.swift), so the two agree.
for (const file of readdirSync(fixtures).filter((name) => name.endsWith(".json"))) {
  test(`manifest fixture ${file}`, () => {
    const { manifest, problems } = JSON.parse(readFileSync(join(fixtures, file), "utf8"));
    if (problems.length === 0) {
      assert.doesNotThrow(() => validateManifest(manifest));
      return;
    }
    assert.throws(() => validateManifest(manifest), (error) => {
      assert.ok(error instanceof InvalidManifest);
      assert.deepEqual([...error.problems].sort(), [...problems].sort());
      return true;
    });
  });
}

test("the built manifest records the API version and lowercases hosts", () => {
  const { manifest } = JSON.parse(readFileSync(join(fixtures, "valid.json"), "utf8"));
  const built = builtManifest(validateManifest(manifest), "1.0.0");
  assert.deepEqual(built.orbtorrent, { api: "1.0.0" });
  assert.deepEqual(built.permissions, { network: ["api.example.com"] });
});

test("settings get types and values", () => {
  const manifest = validateManifest({
    name: "x", title: "T", description: "D", author: "A", hooks: [{ name: "check", event: "afterFinish" }],
    preferences: [
      { name: "apiKey", type: "password", title: "Key", required: true },
      { name: "scope", type: "dropdown", title: "Scope", data: [{ title: "Risky", value: "risky" }, { title: "All", value: "all" }] },
      { name: "upload", type: "checkbox", title: "Upload" },
    ],
  });
  const types = environmentDeclarations(manifest);
  assert.match(types, /apiKey: string;/);
  assert.match(types, /scope: "risky" \| "all";/);
  assert.match(types, /upload: boolean;/);
  assert.deepEqual(defaultPreferences(manifest), { apiKey: "", scope: "risky", upload: false });
});
