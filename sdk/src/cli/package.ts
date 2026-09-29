import { spawnSync } from "node:child_process";
import { rmSync } from "node:fs";
import { join } from "node:path";
import { build } from "./build.js";
import { AppConnection, appName, bundleIdentifier } from "./connection.js";
import { CommandError } from "./output.js";

/** Builds, then zips dist/ into <name>.orbext for installing on another Mac. */
export async function packageExtension(folder: string): Promise<string> {
  const built = await build(folder);
  const archive = join(folder, `${built.manifest.name}.orbext`);
  rmSync(archive, { force: true });
  const result = spawnSync("/usr/bin/ditto", ["-c", "-k", "--norsrc", built.dist, archive], { encoding: "utf8" });
  if (result.error) throw new CommandError("The .orbext file couldn't be made: it needs macOS's ditto.", [result.error.message]);
  if (result.status !== 0) throw new CommandError("The .orbext file couldn't be made.", [result.stderr.trim()]);
  return archive;
}

/**
 * Packages the extension and asks OrbTorrent to install it. OrbTorrent shows
 * what it does and what it can reach, and only the user can say yes: with the
 * development connection, this waits for their answer. Without it, it opens
 * the file in OrbTorrent, which shows the same sheet, and doesn't wait.
 */
export async function installExtension(folder: string, onWaiting: () => void): Promise<{ archive: string; installed: boolean }> {
  const archive = await packageExtension(folder);
  let connection: AppConnection | undefined;
  try {
    connection = await AppConnection.open();
  } catch {
    connection = undefined;
  }
  if (connection) {
    const timer = setTimeout(onWaiting, 1500);
    try {
      await connection.request({ type: "install", path: archive }, ["installed"]);
      return { archive, installed: true };
    } catch (error) {
      // An OrbTorrent from before `orb install` opens the file instead.
      if (!(error instanceof CommandError && error.message.includes("doesn't know that request"))) throw error;
    } finally {
      clearTimeout(timer);
      connection.close();
    }
  }
  const result = spawnSync("/usr/bin/open", ["-b", bundleIdentifier, archive], { encoding: "utf8" });
  if (result.status !== 0) {
    throw new CommandError(`${appName} couldn't be opened to install it.`, [result.stderr?.trim(), "`orb doctor` checks that it's installed."].filter(Boolean) as string[]);
  }
  return { archive, installed: false };
}
