// Pages as Markdown, for agents that ask for it.
import assert from "node:assert/strict";
import { test } from "node:test";
import { markdownFor, wantsMarkdown } from "./markdown.ts";

test("agents that ask for Markdown get it, and browsers never do", () => {
  assert.equal(wantsMarkdown("text/markdown"), true);
  assert.equal(wantsMarkdown("text/markdown, text/html;q=0.9, */*;q=0.8"), true);
  assert.equal(wantsMarkdown("text/html, text/markdown"), true);
  assert.equal(wantsMarkdown("TEXT/MARKDOWN; charset=utf-8"), true);

  assert.equal(wantsMarkdown(null), false);
  assert.equal(wantsMarkdown("*/*"), false);
  assert.equal(wantsMarkdown("text/*"), false);
  assert.equal(wantsMarkdown("text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"), false);
  assert.equal(wantsMarkdown("text/html, text/markdown;q=0.5"), false);
  assert.equal(wantsMarkdown("text/markdown;q=0"), false);
});

test("docs pages have their own Markdown, and the homepage has llms.txt", () => {
  assert.equal(markdownFor("/"), "/llms.txt");
  assert.equal(markdownFor("/index.html"), "/llms.txt");
  assert.equal(markdownFor("/docs"), "/docs.md");
  assert.equal(markdownFor("/docs/"), "/docs.md");
  assert.equal(markdownFor("/docs/guides/vpn"), "/docs/guides/vpn.md");
  assert.equal(markdownFor("/docs/guides/vpn.html"), "/docs/guides/vpn.md");
});

test("other pages and files stay as they are", () => {
  for (const path of ["/faq", "/download", "/docs/guides/vpn.md", "/docs/extensions/llms-full.txt", "/og/home.png", "/download/mac"]) {
    assert.equal(markdownFor(path), null, path);
  }
});
