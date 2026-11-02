// Which requests reach the Worker. Without run_worker_first in wrangler.jsonc,
// the files answer first, and an address with no file gets the not-found page
// without the Worker seeing it.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { site } from "./site.ts";

const wrangler = readFileSync(new URL("../../wrangler.jsonc", import.meta.url), "utf8");
const config = JSON.parse(wrangler.split("\n").filter((line) => !line.trim().startsWith("//")).join("\n"));
const rules: string[] = config.assets.run_worker_first;

/** Whether run_worker_first sends a request for the path to the Worker: a rule with ! keeps it from it. */
function reachesWorker(path: string): boolean {
  const covers = (rule: string) => (rule.endsWith("*") ? path.startsWith(rule.slice(0, -1)) : path === rule);
  return rules.some((rule) => !rule.startsWith("!") && covers(rule)) && !rules.some((rule) => rule.startsWith("!") && covers(rule.slice(1)));
}

test("the Worker sees the download link, the sign-up's posts, the film, the homepage and the docs first", () => {
  for (const path of [site.download, "/subscribe", "/subscribe/confirm", "/unsubscribe", "/film/orbtorrent.mp4", "/", "/docs", "/docs/guides/vpn"]) {
    assert.ok(reachesWorker(path), `${path} doesn't reach the Worker first`);
  }
});

test("other pages, scripts, styles and pictures go straight to the files", () => {
  for (const path of ["/faq", "/_astro/page.js", "/og/home.png", "/brand/orb.webp", "/press/orbtorrent-icon.png", "/pagefind/pagefind.js"]) {
    assert.ok(!reachesWorker(path), `${path} reaches the Worker`);
  }
});
