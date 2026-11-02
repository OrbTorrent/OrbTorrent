// Which requests for /download/mac the Worker counts as a download
// (src/worker.ts): a person clicking Download, or typing the address.

/**
 * Whether the request is a browser opening the link as a page, which every
 * browser of the last few years says with Sec-Fetch-Mode: navigate, and most
 * robots don't, even those that say they're a browser. Not a prefetch, a
 * page's script fetching it, or a robot that says what it is.
 */
export function isCounted(request: Request): boolean {
  const agent = request.headers.get("User-Agent") ?? "";
  const purpose = `${request.headers.get("Sec-Purpose") ?? ""} ${request.headers.get("Purpose") ?? ""}`;
  if (request.method !== "GET" || request.headers.get("Sec-Fetch-Mode") !== "navigate" || purpose.includes("prefetch")) return false;
  return agent.startsWith("Mozilla/") && !/bot|crawl|spider|slurp|preview|headless|lighthouse/i.test(agent);
}
