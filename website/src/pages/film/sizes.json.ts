// The size of each film in public/film/, in bytes, measured as the site is
// built. The Worker needs it to answer a byte range, and the files' own
// responses don't say (src/lib/ranges.ts).
import type { APIRoute } from "astro";
import { readdirSync, statSync } from "node:fs";
import { join } from "node:path";

const folder = join(process.cwd(), "public/film");

export const GET: APIRoute = () => {
  const sizes = Object.fromEntries(
    readdirSync(folder)
      .filter((name) => name.endsWith(".mp4"))
      .map((name) => [name, statSync(join(folder, name)).size]),
  );
  return new Response(JSON.stringify(sizes), { headers: { "Content-Type": "application/json" } });
};
