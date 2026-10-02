// Keeps the API reference whole: every export of @orbtorrent/api, in
// ../sdk/src/index.ts, needs a heading of its own on the API page. A build
// stops when one doesn't, so the docs can't fall behind the SDK.

import { readFileSync } from "node:fs";

const sdk = new URL("../../../sdk/src/index.ts", import.meta.url);
const page = new URL("../content/docs/docs/extensions/reference/api.md", import.meta.url);

/** The names @orbtorrent/api exports. */
export function apiExports(source = readFileSync(sdk, "utf8")) {
  return [...source.matchAll(/^export\s+(?:async\s+)?(?:function|const|class|interface|type)\s+(\w+)/gm)].map((match) => match[1]);
}

/** The names the API page gives a heading, such as "### `fetch`". */
export function documentedNames(markdown = readFileSync(page, "utf8")) {
  return new Set([...markdown.matchAll(/^#{2,4}\s+`([\w.]+)`/gm)].map((match) => match[1]));
}

/** @returns {import("astro").AstroIntegration} */
export function checkApiDocs() {
  return {
    name: "orbtorrent:api-docs",
    hooks: {
      "astro:config:setup": ({ command, logger }) => {
        const documented = documentedNames();
        const missing = apiExports().filter((name) => !documented.has(name));
        if (missing.length === 0) return;
        const message = `The API reference doesn't cover ${missing.map((name) => `\`${name}\``).join(", ")}. Add a heading for each to src/content/docs/docs/extensions/reference/api.md.`;
        if (command === "build") throw new Error(message);
        logger.warn(message);
      },
    },
  };
}
