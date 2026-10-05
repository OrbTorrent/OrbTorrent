// @ts-check
import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";
import starlight from "@astrojs/starlight";
import starlightLinksValidator from "starlight-links-validator";
import tailwindcss from "@tailwindcss/vite";
import { sidebar } from "./src/lib/docs-sidebar.mjs";
import { checkApiDocs } from "./src/lib/check-api-docs.mjs";

// orbtorrent.com: every page is built ahead of time, as files. A small
// Worker, src/worker.ts, answers /download/mac, which sends people to the
// newest release, and Cloudflare serves the rest.
//
// The docs, at /docs, are Starlight: Markdown in src/content/docs/docs/,
// drawn in the site's own paper and ink.
export default defineConfig({
  site: "https://orbtorrent.com",
  trailingSlash: "never",
  build: { format: "file", inlineStylesheets: "always" },

  integrations: [
    starlight({
      title: "OrbTorrent Docs",
      description: "How to use OrbTorrent, the torrent app made for the Mac, and how to build extensions for it.",
      titleDelimiter: "·",
      locales: { root: { label: "English", lang: "en-GB" } },
      // The site has its own not-found page.
      disable404Route: true,
      credits: false,
      favicon: "/favicon.png",
      head: [
        { tag: "link", attrs: { rel: "icon", href: "/favicon.ico", sizes: "32x32" } },
        { tag: "link", attrs: { rel: "apple-touch-icon", href: "/apple-touch-icon.png" } },
        { tag: "link", attrs: { rel: "manifest", href: "/site.webmanifest" } },
        { tag: "link", attrs: { rel: "sitemap", href: "/sitemap-index.xml" } },
      ],
      editLink: { baseUrl: "https://github.com/sanjevirau/OrbTorrent/edit/main/website/" },
      lastUpdated: true,
      markdown: { headingLinks: true },
      customCss: ["./src/styles/docs.css"],
      // Link previews, structured data and the Markdown copy of each page.
      routeMiddleware: "./src/lib/docs-route.ts",
      components: {
        Head: "./src/components/docs/Head.astro",
        SiteTitle: "./src/components/docs/SiteTitle.astro",
        SocialIcons: "./src/components/docs/SocialIcons.astro",
        Search: "./src/components/docs/Search.astro",
        PageTitle: "./src/components/docs/PageTitle.astro",
        Hero: "./src/components/docs/Hero.astro",
        Footer: "./src/components/docs/Footer.astro",
      },
      expressiveCode: {
        themes: ["github-dark-default", "github-light-default"],
        styleOverrides: {
          borderRadius: "0.75rem",
          borderColor: "var(--sl-color-hairline-light)",
          codeFontFamily: "var(--__sl-font-mono)",
          codeFontSize: "0.8125rem",
          uiFontFamily: "var(--__sl-font)",
          frames: {
            shadowColor: "transparent",
            editorActiveTabIndicatorTopColor: "var(--sl-color-accent)",
            terminalTitlebarBackground: "var(--docs-code-titlebar)",
            editorTabBarBackground: "var(--docs-code-titlebar)",
          },
        },
      },
      sidebar,
      plugins: [
        // Every link between pages, and to a heading on one, must lead
        // somewhere. The site's own pages and files aren't docs, so they're
        // left out.
        starlightLinksValidator({
          exclude: ["/", "/download", "/download/mac", "/extensions", "/switch", "/utorrent-for-mac", "/qbittorrent-for-mac", "/transmission-for-mac", "/privacy", "/privacy#counts", "/faq", "/press", "/how-its-built", "/*.txt", "/docs/**/*.txt", "/docs/**/*.md", "/docs.md"],
        }),
      ],
    }),
    // Not the not-found page, or the email sign-up's steps.
    sitemap({ filter: (page) => !page.includes("/404") && !/\/(un)?subscribe(\/|$)/.test(page) }),
    // Every export of @orbtorrent/api has its place in the API reference.
    checkApiDocs(),
  ],

  vite: {
    plugins: [tailwindcss()],
    build: {
      rolldownOptions: {
        // Each MDX page carries a directive for Astro's own bundling, which
        // the bundler warns it can't keep. It doesn't need to.
        onwarn(warning, warn) {
          if (warning.code !== "MODULE_LEVEL_DIRECTIVE") warn(warning);
        },
      },
    },
  },
});