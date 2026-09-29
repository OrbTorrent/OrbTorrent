import { spawnSync } from "node:child_process";
import { rmSync } from "node:fs";
import { join } from "node:path";
import { build } from "./build.js";
import { CommandError } from "./output.js";

/** Builds, then zips dist/ into <name>.orbext for installing on another Mac. */
export async function packageExtension(folder: string): Promise<string> {
  const built = await build(folder);
  const archive = join(folder, `${built.manifest.name}.orbext`);
  rmSync(archive, { force: true });
  const result = spawnSync("/usr/bin/ditto", ["-c", "-k", "--norsrc", built.dist, archive], { encoding: "utf8" });
  if (result.status !== 0) throw new CommandError("The .orbext file couldn't be made.", [result.stderr.trim()]);
  return archive;
}
