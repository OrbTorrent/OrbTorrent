// Which requests reach the Worker. The files answer first, and an address
// with no file gets the not-found page without the Worker seeing it, unless
// wrangler.jsonc lists it in run_worker_first.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { site } from "./site.ts";

const wrangler = readFileSync(new URL("../../wrangler.jsonc", import.meta.url), "utf8");
const config = JSON.parse(wrangler.split("\n").filter((line) => !line.trim().startsWith("//")).join("\n"));

test("the Worker sees the download link, the sign-up's posts and the film first", () => {
  const first: string[] = config.assets.run_worker_first;
  for (const path of [site.download, "/subscribe", "/subscribe/confirm", "/unsubscribe", "/film/*"]) {
    assert.ok(first.includes(path), `${path} isn't in run_worker_first`);
  }
});
