// The Agent Skill in ../skills/, published where agents look for a site's
// skills (https://github.com/cloudflare/agent-skills-discovery-rfc, v0.2.0):
// an index at /.well-known/agent-skills/index.json, and the skill as a
// .tar.gz archive, since its SKILL.md sends agents to a reference file
// beside it. Both are made with the site, so they always match the repo.

import { createHash } from "node:crypto";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";
import { gzipSync } from "node:zlib";

export const skillName = "build-orbtorrent-extension";
export const skillsPath = "/.well-known/agent-skills";

/** The skill's files, by their path inside it, in a fixed order. */
export function skillFiles(folder = resolve(process.cwd(), "../skills", skillName)): { path: string; contents: Uint8Array }[] {
  return readdirSync(folder, { recursive: true, encoding: "utf8" })
    .filter((path) => statSync(join(folder, path)).isFile())
    .sort()
    .map((path) => ({ path: path.split("\\").join("/"), contents: readFileSync(join(folder, path)) }));
}

/**
 * The files as a gzip-compressed tar, with SKILL.md at its root. It's the same
 * bytes every time: no dates, owners or permissions from the Mac that made it.
 */
export function tarGz(files: { path: string; contents: Uint8Array }[]): Uint8Array {
  const blocks: Uint8Array[] = [];
  for (const file of files) {
    const header = new Uint8Array(512);
    const put = (text: string, at: number) => header.set(new TextEncoder().encode(text), at);
    if (file.path.length > 100 || file.path.split("/").includes("..")) throw new Error(`Can't archive ${file.path}`);
    put(file.path, 0);
    put("0000644\0", 100);
    put("0000000\0", 108);
    put("0000000\0", 116);
    put(`${file.contents.length.toString(8).padStart(11, "0")}\0`, 124);
    put("00000000000\0", 136);
    // The checksum counts its own field as spaces.
    put("        ", 148);
    put("0", 156);
    put("ustar\0", 257);
    put("00", 263);
    put(`${header.reduce((sum, byte) => sum + byte, 0).toString(8).padStart(6, "0")}\0 `, 148);
    blocks.push(header, file.contents, new Uint8Array((512 - (file.contents.length % 512)) % 512));
  }
  blocks.push(new Uint8Array(1024));
  return gzipSync(Buffer.concat(blocks));
}

/** The skill's archive, and the index that lists it with its digest. */
export function skillsIndex(archive = tarGz(skillFiles()), files = skillFiles()) {
  const skill = new TextDecoder().decode(files.find((file) => file.path === "SKILL.md")!.contents);
  const description = /^description: (.+)$/m.exec(skill)?.[1].trim() ?? "";
  return {
    $schema: "https://schemas.agentskills.io/discovery/0.2.0/schema.json",
    skills: [
      {
        name: skillName,
        type: "archive",
        description,
        url: `${skillsPath}/${skillName}.tar.gz`,
        digest: `sha256:${createHash("sha256").update(archive).digest("hex")}`,
      },
    ],
  };
}
