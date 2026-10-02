import type { APIRoute } from "astro";
import { llmsIndex, text } from "../lib/llms";

export const GET: APIRoute = async () => text(await llmsIndex());
