// Each docs page's link preview: its title and description.

import type { APIRoute, GetStaticPaths } from "astro";
import { getCollection } from "astro:content";
import { drawCard } from "../../../lib/og";

export const getStaticPaths: GetStaticPaths = async () =>
  (await getCollection("docs")).map((entry) => ({
    // docs is the start of the docs, docs/extensions/hooks a page in them.
    params: { slug: entry.id === "docs" ? "index" : entry.id.slice("docs/".length) },
    props: { title: entry.data.title, subtitle: entry.data.description },
  }));

export const GET: APIRoute = ({ props }) => drawCard({ title: props.title, subtitle: props.subtitle, section: "Docs" });
