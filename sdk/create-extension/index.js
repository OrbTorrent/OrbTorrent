#!/usr/bin/env node
// `npm create @orbtorrent/extension <name>` runs this. It makes the extension
// with `orb create` from the newest @orbtorrent/api on npm, which the new
// extension then depends on. It asks npm for it each time, because npm reuses
// this package once it has it, with whatever @orbtorrent/api came with it.
import { spawnSync } from "node:child_process";

const args = process.argv.slice(2);
if (args.length === 0 || args.includes("--help") || args.includes("-h")) {
  console.log(`Make a new OrbTorrent extension:

  npm create @orbtorrent/extension <name>
  npm create @orbtorrent/extension <name> -- --template after-finish

Templates: before-start (the default) holds downloads before they start;
after-finish acts on them once they finish. Add -- --title "<title>" to name it.`);
  process.exit(args.length === 0 ? 1 : 0);
}

const { status, error } = spawnSync("npx", ["--yes", "@orbtorrent/api@latest", "create", ...args], { stdio: "inherit" });
if (error) console.error(`npx couldn't run: ${error.message}. It comes with Node.js 22.13 or later.`);
process.exit(status ?? 1);
