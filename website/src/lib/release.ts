// The newest release in a Sparkle update feed, for the Worker to send the
// Download button to. The site itself never shows a version, so it never goes
// out of date when a release is published.

export interface Release {
  version: string;
  /** The disk image, on GitHub. */
  url: string;
}

/** The first item in a Sparkle feed, which lists the newest first. */
export function parseFeed(xml: string): Release | null {
  const item = xml.match(/<item>([\s\S]*?)<\/item>/)?.[1];
  if (!item) return null;
  const url = item.match(/<enclosure[^>]*\surl="([^"]+)"/)?.[1];
  if (!url) return null;
  const version = item.match(/<sparkle:shortVersionString>([^<]*)<\/sparkle:shortVersionString>/)?.[1]?.trim() ?? "";
  return { version, url };
}
