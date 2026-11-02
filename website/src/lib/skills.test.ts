// The Agent Skill as agents find it on the site: its index and its archive.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { gunzipSync } from "node:zlib";
import { skillFiles, skillName, skillsIndex, tarGz } from "./skills.ts";

const files = skillFiles();

test("the archive has the skill's files, with SKILL.md at its root", () => {
  assert.ok(files.some((file) => file.path === "SKILL.md"));
  assert.ok(files.some((file) => file.path === "references/AGENTS.md"));

  const folder = mkdtempSync(join(tmpdir(), "skill-"));
  try {
    writeFileSync(join(folder, "skill.tar.gz"), tarGz(files));
    execFileSync("tar", ["-xzf", "skill.tar.gz"], { cwd: folder });
    for (const file of files) {
      assert.deepEqual(readFileSync(join(folder, file.path)), Buffer.from(file.contents), file.path);
    }
  } finally {
    rmSync(folder, { recursive: true, force: true });
  }
});

test("the archive is the same bytes every time, so its digest holds", () => {
  assert.deepEqual(tarGz(files), tarGz(skillFiles()));
  const tar = gunzipSync(tarGz(files));
  assert.equal(tar.length % 512, 0);
});

test("the index lists the skill with its archive's digest", () => {
  const archive = tarGz(files);
  const index = skillsIndex(archive, files);
  assert.equal(index.$schema, "https://schemas.agentskills.io/discovery/0.2.0/schema.json");
  assert.equal(index.skills.length, 1);
  const [skill] = index.skills;
  const frontmatter = new TextDecoder().decode(files.find((file) => file.path === "SKILL.md")!.contents);
  assert.match(frontmatter, new RegExp(`^name: ${skill.name}$`, "m"));
  assert.equal(skill.name, skillName);
  assert.equal(skill.type, "archive");
  assert.match(frontmatter, new RegExp(`^description: ${skill.description.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "m"));
  assert.equal(skill.url, `/.well-known/agent-skills/${skillName}.tar.gz`);
  assert.equal(skill.digest, `sha256:${createHash("sha256").update(archive).digest("hex")}`);
});
