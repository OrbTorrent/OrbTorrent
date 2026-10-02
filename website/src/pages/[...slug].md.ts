// Each docs page as Markdown, at its own address plus .md, for language
// models and for the Copy page button.

import type { APIRoute, GetStaticPaths } from "astro";
import { getCollection } from "astro:content";
import { pageMarkdown } from "../lib/docs-markdown";

export const getStaticPaths: GetStaticPaths = async () =>
  (await getCollection("docs")).map((entry) => ({ params: { slug: entry.id }, props: { entry } }));

export const GET: APIRoute = ({ props }) =>
  new Response(pageMarkdown(props.entry), { headers: { "Content-Type": "text/markdown; charset=utf-8" } });
