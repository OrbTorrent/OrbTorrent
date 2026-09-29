#!/usr/bin/env node
// `npm create @orbtorrent/extension <name>` runs this. It makes the extension
// with `orb create` from the newest @orbtorrent/api, which the new extension
// then depends on.
import { spawnSync } from "node:child_process";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const args = process.argv.slice(2);
if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
  console.log(`Make a new OrbTorrent extension:

  npm create @orbtorrent/extension <name>
  npm create @orbtorrent/extension <name> -- --template after-finish

Templates: before-start (the default) holds downloads before they start;
after-finish acts on them once they finish. Add -- --title "<title>" to name it.`);
  process.exit(args.length === 0 ? 1 : 0);
}

const api = dirname(fileURLToPath(import.meta.resolve("@orbtorrent/api/package.json")));
const { status } = spawnSync(process.execPath, [join(api, "bin", "orb.js"), "create", ...args], { stdio: "inherit" });
process.exit(status ?? 1);
