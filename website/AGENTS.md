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
  of them, configured in `wrangler.jsonc`. It sees every page first, but only
  answers `/download/mac`, the email sign-up's posts, the film's byte ranges
  and agents asking for Markdown; everything else is the file. Scripts, styles
  and pictures skip it (`run_worker_first`, tested by `npm test`). `npm run deploy` builds the site and
  publishes it with Wrangler. Not `cf deploy`: it adds Cloudflare's Astro
  adapter to the project, which this site doesn't use. Once the repo is
  public, a push to main that changes the site deploys it from CI
  (`.github/workflows/website.yml`).
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
  from the docs (`src/lib/llms.ts`). A request with `Accept: text/markdown`
  gets a docs page's Markdown, or `llms.txt` for the homepage
  (`src/lib/markdown.ts`); other pages stay HTML. The homepage's `Link` header
  (`public/_headers`) points agents to `llms.txt` and the Agent Skills index.
- The Agent Skill in `../skills/` is published at
  `/.well-known/agent-skills/` (`src/lib/skills.ts`): an index, and the skill
  as a `.tar.gz` with its digest, made with the site.
- The Download buttons carry `data-download`: on a Mac they start the
  download straight away, without leaving the page, and show a note
  (`src/components/DownloadStarted.astro`); elsewhere they open `/download`.
  The Worker counts each download in Analytics Engine, and `./stats.sh` shows
  them. Give a link straight to `/download/mac` `data-astro-prefetch="false"`,
  since hovering over a link fetches it ahead of time.
- The site never shows a version number, so publishing a release never needs
  the site rebuilt. Only the Worker reads the update feed, live.
- The homepage's "Watch the film" (`src/components/Film.astro`) plays the
  launch film from `public/film/`, made in `../video/`, whose README says
  how. Workers' static assets ignore byte ranges, which Safari needs to play
  a video, so the Worker sees `/film/*` first and answers them
  (`src/lib/ranges.ts`, tested by `npm test`), with each film's size from
  `/film/sizes.json`, measured at build. A file there can be at most 25 MiB,
  and a new cut needs a new name, set in `site.film`.
- Pages are counted by Cloudflare Web Analytics (`src/components/Analytics.astro`),
  only on orbtorrent.com. The privacy page says what's counted: change it when
  that changes. Its Web Analytics site is added by hostname, not through the
  zone: a zone's site also adds Cloudflare's own copy of the script to every
  page, including those never counted, and stops counting when that's off.
- The app's anonymous counts (`OrbTorrent/Updates/AnonymousCounts.swift`) are
  listed value by value on the privacy page (`#counts`) and summed up in
  `guides/privacy.md`, `guides/updates.md`, the FAQ and
  `src/pages/how-its-built.astro`. The app's About ›
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
