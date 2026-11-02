// Agents ask for a page as Markdown with Accept: text/markdown, as Cloudflare's
// Markdown for Agents answers it. The Worker (src/worker.ts) answers with the
// site's own Markdown where there is some: each docs page's copy, made with
// the site at its address plus .md, and llms.txt for the homepage. Other pages
// stay HTML, which is still a correct answer.

/** Each type's preference in an Accept header, from 0 to 1. */
function preferences(accept: string): Map<string, number> {
  const types = new Map<string, number>();
  for (const part of accept.split(",")) {
    const [type, ...parameters] = part.split(";").map((piece) => piece.trim().toLowerCase());
    const q = parameters.find((parameter) => parameter.startsWith("q="));
    const quality = q ? Number(q.slice(2)) : 1;
    if (type && Number.isFinite(quality)) types.set(type, Math.max(types.get(type) ?? 0, quality));
  }
  return types;
}

/**
 * Whether a request asks for Markdown at least as much as HTML. Only one that
 * names text/markdown does: browsers never do, and a wildcard isn't asking.
 */
export function wantsMarkdown(accept: string | null): boolean {
  if (!accept) return false;
  const types = preferences(accept);
  const markdown = types.get("text/markdown") ?? 0;
  return markdown > 0 && markdown >= (types.get("text/html") ?? 0);
}

/** The file with a page's Markdown, or null for a page without its own. */
export function markdownFor(pathname: string): string | null {
  const path = pathname.replace(/\.html$/, "").replace(/\/+$/, "") || "/";
  // A file, such as a picture or a docs page's .md itself, is already what it is.
  if (/\.[a-z0-9]+$/i.test(path)) return null;
  if (path === "/" || path === "/index") return "/llms.txt";
  if (path === "/docs" || path.startsWith("/docs/")) return `${path}.md`;
  return null;
}
