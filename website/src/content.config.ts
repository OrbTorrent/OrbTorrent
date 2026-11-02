import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { defineCollection } from "astro:content";
import { z } from "astro/zod";
import { docsLoader, i18nLoader } from "@astrojs/starlight/loaders";
import { docsSchema, i18nSchema } from "@astrojs/starlight/schema";

// The docs, at /docs: Markdown and MDX in src/content/docs/docs/.
export const collections = {
  docs: defineCollection({
    loader: docsLoader(),
    schema: docsSchema({
      extend: z.object({
        // Every page has its own description, for search results and link
        // previews, short enough for search results to show it whole.
        description: z.string().max(160),
      }),
    }),
  }),
  // The extension SDK's changelog, from sdk/CHANGELOG.md, which the docs'
  // Changelog page shows, so it's written once.
  sdkChangelog: defineCollection({
    loader: {
      name: "sdk-changelog",
      load: async ({ store, renderMarkdown, generateDigest, watcher }) => {
        const file = resolve(process.cwd(), "../sdk/CHANGELOG.md");
        const load = async () => {
          // Its own title gives way to the page's.
          const body = readFileSync(file, "utf8").replace(/^# .*\n+/, "");
          store.set({ id: "sdk", data: {}, body, rendered: await renderMarkdown(body), digest: generateDigest(body) });
        };
        await load();
        watcher?.add(file);
        watcher?.on("change", (path) => {
          if (path === file) void load();
        });
      },
    },
  }),
  // Starlight's own words, such as "Edit page", in OrbTorrent's.
  i18n: defineCollection({ loader: i18nLoader(), schema: i18nSchema() }),
};
