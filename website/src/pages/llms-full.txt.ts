import type { APIRoute } from "astro";
import { llmsFull, text } from "../lib/llms";

export const GET: APIRoute = async () => text(await llmsFull());
