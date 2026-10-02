## Development

When starting the dev server, use background mode:

```
astro dev --background
```

Manage the background server with `astro dev stop`, `astro dev status`, and `astro dev logs`.

## Documentation

Full documentation: https://docs.astro.build

Consult these guides before working on related tasks:

- [Adding pages, dynamic routes, or middleware](https://docs.astro.build/en/guides/routing/)
- [Working with Astro components](https://docs.astro.build/en/basics/astro-components/)
- [Using React, Vue, Svelte, or other framework components](https://docs.astro.build/en/guides/framework-components/)
- [Adding or managing content](https://docs.astro.build/en/guides/content-collections/)
- [Adding styles or using Tailwind](https://docs.astro.build/en/guides/styling/)
- [Supporting multiple languages](https://docs.astro.build/en/guides/internationalization/)

## This site

- Every page is built ahead of time, as files (`build.format: "file"`,
  `trailingSlash: "never"`). `src/worker.ts` is the Cloudflare Worker in front
  of them, which only answers `/download/mac` and the email sign-up's posts,
  configured in `wrangler.jsonc`. `npm run deploy` builds the site and
  publishes it with Wrangler. Not `cf deploy`: it adds Cloudflare's Astro
  adapter to the project, which this site doesn't use.
- The docs at `/docs` are Starlight. Pages are Markdown in
  `src/content/docs/docs/`, the sidebar is `src/lib/docs-sidebar.mjs`, the
  theme is `src/styles/docs.css`, and overridden Starlight components are in
  `src/components/docs/`. `src/lib/docs-route.ts` cleans links, and adds each
  page's preview image, structured data and Markdown link.
- Every docs page needs a `title` and a `description` of 160 characters or
  fewer. Write in plain British English, and check every fact against the
  app's or the SDK's source.
- `npm run build` fails on a broken link between docs pages, or when the API
  reference (`src/content/docs/docs/extensions/reference/api.md`) is missing
  an export of `../sdk/src/index.ts`.
- Each docs page is also served as Markdown at its address plus `.md`, and
  `llms.txt`, `llms-full.txt` and `docs/extensions/llms*.txt` are generated
  from the docs (`src/lib/llms.ts`).
- The Download buttons carry `data-download`: on a Mac they start the
  download straight away, without leaving the page, and show a note
  (`src/components/DownloadStarted.astro`); elsewhere they open `/download`.
  The Worker counts each download in Analytics Engine, and `./stats.sh` shows
  them. Give a link straight to `/download/mac` `data-astro-prefetch="false"`,
  since hovering over a link fetches it ahead of time.
- The site never shows a version number, so publishing a release never needs
  the site rebuilt. Only the Worker reads the update feed, live.
- Pages are counted by Cloudflare Web Analytics (`src/components/Analytics.astro`),
  only on orbtorrent.com. The privacy page says what's counted: change it when
  that changes.
- The app's anonymous counts (`OrbTorrent/Updates/AnonymousCounts.swift`) are
  listed value by value on the privacy page (`#counts`) and summed up in
  `guides/privacy.md`, `guides/updates.md` and the FAQ. The app's About ›
  Privacy and "See What's Sent", the README and `updates/src/counts.ts` say the
  same. Change them all together.
- The email sign-up, "Hear about big releases", is in the footer
  (`src/components/SignUp.astro`). The Worker keeps each address in the D1
  database `orbtorrent-newsletter` (in the EU; `migrations/`), and sends a
  link to confirm it through Cloudflare Email Service, as hello@orbtorrent.com
  (`src/lib/newsletter.ts`, tested by `npm test`). Each step's page is in
  `src/pages/subscribe/` and `src/pages/unsubscribe*`, never indexed or
  counted. The email is React Email (`emails/`), built by `npm run emails`,
  which `npm run build` runs first. `./newsletter.sh` counts and exports the
  list. Cloudflare Email Service is only for emails like the confirmation, so
  the 1.0 email itself goes out through a newsletter service; then the
  privacy page's `#emails` must name it. Change that section with any change
  to what's kept or who sends.
- Starlight sets Astro's `scopedStyleStrategy` to `"where"` for the whole
  site. In that mode, a component given a `class` also takes its parent's
  scope, so the parent's scoped styles can reach it. Name a component's own
  classes for it alone, such as `.download-button`, never a word a page might
  use too.
