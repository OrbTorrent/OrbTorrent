import { Download, Result, getPreferenceValues } from "@orbtorrent/api";

const gigabyte = 1_000_000_000;

/** Runs when a download's files are known, before any of it downloads. */
export default async function check(download: Download): Promise<Result> {
  const { limit } = getPreferenceValues();
  const size = (download.size / gigabyte).toFixed(1);
  if (download.size > Number(limit) * gigabyte) {
    // "failed" holds the download until the user starts it.
    return { status: "failed", summary: `It's ${size} GB, more than your ${limit} GB limit` };
  }
  return { status: "passed", summary: `${size} GB, within your ${limit} GB limit` };
}
