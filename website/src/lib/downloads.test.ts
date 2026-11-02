// Which visits to /download/mac count as a download.
import assert from "node:assert/strict";
import { test } from "node:test";
import { isCounted } from "./downloads.ts";

const safari = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15";

function visit(headers: Record<string, string>, method = "GET"): Request {
  return new Request("https://orbtorrent.com/download/mac", { method, headers });
}

test("a click or a typed address in a browser counts", () => {
  assert.equal(isCounted(visit({ "User-Agent": safari, "Sec-Fetch-Mode": "navigate", "Sec-Fetch-Dest": "document" })), true);
});

test("a robot that says it's a browser, without a browser's page visit, doesn't", () => {
  assert.equal(isCounted(visit({ "User-Agent": safari })), false);
});

test("prefetches, scripts, other methods and robots that say what they are don't", () => {
  assert.equal(isCounted(visit({ "User-Agent": safari, "Sec-Fetch-Mode": "navigate", "Sec-Purpose": "prefetch" })), false);
  assert.equal(isCounted(visit({ "User-Agent": safari, "Sec-Fetch-Mode": "cors" })), false);
  assert.equal(isCounted(visit({ "User-Agent": safari, "Sec-Fetch-Mode": "navigate" }, "HEAD")), false);
  for (const agent of [
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/150.0.0.0 Safari/537.36",
    "curl/8.7.1",
  ]) {
    assert.equal(isCounted(visit({ "User-Agent": agent, "Sec-Fetch-Mode": "navigate" })), false, agent);
  }
});
