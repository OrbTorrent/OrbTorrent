import { env } from "cloudflare:workers";

// OrbTorrent's update feed. Each installed copy asks for /appcast.xml once a
// day. The feed is passed on exactly as it was signed, and each request is
// counted by the version and build in its user agent, such as
// "OrbTorrent/1.0 (2) Sparkle/2.10.0", and nothing else: not the address it
// came from, so we know how many Macs use each version and nothing about who.
//
// /test/appcast.xml is a feed for trying updates in OrbTorrent Dev.

const feeds: Record<string, string> = {
	"/appcast.xml": "appcast.xml",
	"/test/appcast.xml": "test-appcast.xml",
};

export default {
	async fetch(request, _env, context) {
		const { pathname } = new URL(request.url);
		const feed = feeds[pathname];
		if (!feed) {
			return pathname === "/"
				? Response.redirect("https://orbtorrent.com/", 302)
				: new Response("Not found\n", { status: 404 });
		}
		if (request.method !== "GET" && request.method !== "HEAD") {
			return new Response(null, { status: 405, headers: { Allow: "GET, HEAD" } });
		}
		const xml = await env.FEEDS.get(feed, { cacheTtl: 60 });
		if (xml === null) return new Response("Not found\n", { status: 404 });
		context.waitUntil(Promise.resolve(count(request, feed)));
		return new Response(request.method === "HEAD" ? null : xml, {
			headers: {
				"Content-Type": "application/xml; charset=utf-8",
				"Cache-Control": "no-cache",
			},
		});
	},
} satisfies ExportedHandler;

function count(request: Request, feed: string) {
	const agent = request.headers.get("User-Agent") ?? "";
	const [, app = "other", version = "", build = ""] =
		agent.match(/^(OrbTorrent(?: Dev)?)\/(\S+) \((\d+)\)/) ?? [];
	env.CHECKS.writeDataPoint({ indexes: [feed], blobs: [app, version, build], doubles: [1] });
}
