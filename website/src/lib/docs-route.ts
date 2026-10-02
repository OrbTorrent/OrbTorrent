// Gives each docs page what the rest of the site has: links to pages at their
// one address, its own link preview image, structured data for search
// engines, and a link to the page as Markdown for language models.

import { defineRouteMiddleware } from "@astrojs/starlight/route-data";
import { site } from "./site";
import { graph, organization, website } from "./schema";
import { markdownPath, pagePath } from "./docs";

/** The page's link preview, drawn by /og/docs/[...slug].png. */
export const ogImagePath = (id: string) => (id === "docs" ? "/og/docs/index.png" : `/og/${id}.png`);

type Route = App.Locals["starlightRoute"];

/** /docs/hooks.html, as Starlight writes links to pages built as files, is /docs/hooks. */
const clean = (href: string) => href.replace(/\.html(?=$|[#?])/, "");

function cleanSidebar(entries: Route["sidebar"]) {
  for (const entry of entries) {
    if (entry.type === "link") entry.href = clean(entry.href);
    else cleanSidebar(entry.entries);
  }
}

export const onRequest = defineRouteMiddleware((context) => {
  const route = context.locals.starlightRoute;
  const { entry, head, lastUpdated, pagination } = route;

  // Links to pages at their one address, without .html.
  cleanSidebar(route.sidebar);
  if (pagination.prev) pagination.prev.href = clean(pagination.prev.href);
  if (pagination.next) pagination.next.href = clean(pagination.next.href);

  const { title, description } = entry.data;
  const url = `${site.url}${pagePath(entry.id)}`;
  const image = `${site.url}${ogImagePath(entry.id)}`;

  // Pages are built as files, docs/hooks.html, and served as /docs/hooks,
  // their one address.
  for (const tag of head) {
    if (tag.tag === "link" && tag.attrs?.rel === "canonical") tag.attrs.href = url;
    if (tag.tag === "meta" && tag.attrs?.property === "og:url") tag.attrs.content = url;
  }

  // Starlight writes the language as en-GB; Open Graph wants en_GB.
  const locale = head.find((tag) => tag.attrs?.property === "og:locale");
  if (locale?.attrs) locale.attrs.content = "en_GB";

  const crumbs = [
    { name: "Home", item: `${site.url}/` },
    { name: "Docs", item: `${site.url}/docs` },
    ...(entry.id.startsWith("docs/extensions/") ? [{ name: "Build extensions", item: `${site.url}/docs/extensions` }] : []),
    ...(entry.id === "docs" ? [] : [{ name: title, item: url }]),
  ];

  const article = {
    "@type": "TechArticle",
    "@id": `${url}#article`,
    headline: title,
    description,
    url,
    image,
    inLanguage: "en-GB",
    isPartOf: { "@id": `${site.url}/#website` },
    publisher: { "@id": `${site.url}/#organization` },
    // OrbTorrent itself, described in full on the home page.
    about: { "@id": `${site.url}/#app` },
    ...(lastUpdated ? { dateModified: lastUpdated.toISOString() } : {}),
  };
  const breadcrumbs = {
    "@type": "BreadcrumbList",
    itemListElement: crumbs.map((crumb, index) => ({ "@type": "ListItem", position: index + 1, name: crumb.name, item: crumb.item })),
  };
  // Kept from closing the script early, whatever a title holds.
  const json = JSON.stringify(graph(organization, website, article, breadcrumbs)).replace(/</g, "\\u003c");

  head.push(
    { tag: "meta", attrs: { property: "og:image", content: image } },
    { tag: "meta", attrs: { property: "og:image:width", content: "1200" } },
    { tag: "meta", attrs: { property: "og:image:height", content: "630" } },
    { tag: "meta", attrs: { property: "og:image:alt", content: `${title}: OrbTorrent Docs` } },
    { tag: "meta", attrs: { name: "twitter:title", content: `${title} · OrbTorrent Docs` } },
    { tag: "meta", attrs: { name: "twitter:description", content: description } },
    { tag: "meta", attrs: { name: "twitter:image", content: image } },
    { tag: "link", attrs: { rel: "alternate", type: "text/markdown", href: markdownPath(entry.id), title: `${title} as Markdown` } },
    { tag: "script", attrs: { type: "application/ld+json" }, content: json },
  );
});
