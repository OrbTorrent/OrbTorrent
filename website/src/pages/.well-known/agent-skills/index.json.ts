// The site's Agent Skills, for agents that look for them (src/lib/skills.ts).

import type { APIRoute } from "astro";
import { skillsIndex } from "../../../lib/skills";

export const GET: APIRoute = () =>
  new Response(`${JSON.stringify(skillsIndex(), null, 2)}\n`, { headers: { "Content-Type": "application/json" } });
