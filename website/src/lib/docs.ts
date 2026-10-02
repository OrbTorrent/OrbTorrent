// What the docs' pages share: where a page sits in the sidebar, and where its
// Markdown copy is.

import type { StarlightRouteData } from "@astrojs/starlight/route-data";

type SidebarEntry = StarlightRouteData["sidebar"][number];

/** The sidebar groups the current page is in, outermost first, such as ["Build extensions", "Reference"]. */
export function sidebarTrail(entries: SidebarEntry[], groups: string[] = []): string[] | undefined {
  for (const entry of entries) {
    if (entry.type === "link" && entry.isCurrent) return groups;
    if (entry.type === "group") {
      const found = sidebarTrail(entry.entries, [...groups, entry.label]);
      if (found) return found;
    }
  }
  return undefined;
}

/** A docs page's address, from its id: "docs/extensions/hooks" is /docs/extensions/hooks. */
export const pagePath = (id: string) => `/${id}`;

/** The page as Markdown, for people and language models: /docs/extensions/hooks.md. */
export const markdownPath = (id: string) => `/${id}.md`;
