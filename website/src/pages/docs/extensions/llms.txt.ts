import type { APIRoute } from "astro";
import { llmsExtensionsIndex, text } from "../../../lib/llms";

export const GET: APIRoute = async () => text(await llmsExtensionsIndex());
