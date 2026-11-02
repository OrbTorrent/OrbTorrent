// The Agent Skill as an archive, which the index lists (src/lib/skills.ts).

import type { APIRoute, GetStaticPaths } from "astro";
import { skillFiles, skillName, tarGz } from "../../../lib/skills";

export const getStaticPaths: GetStaticPaths = () => [{ params: { skill: skillName } }];

export const GET: APIRoute = () =>
  new Response(tarGz(skillFiles()), { headers: { "Content-Type": "application/gzip" } });
