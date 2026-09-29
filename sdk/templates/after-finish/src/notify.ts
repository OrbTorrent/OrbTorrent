import { Download, Result, fetch, getPreferenceValues } from "@orbtorrent/api";

/** Runs once, when every wanted file of a download has finished. */
export default async function notify(download: Download): Promise<Result> {
  const { topic } = getPreferenceValues();
  // Only hosts listed in permissions.network can be reached.
  const response = await fetch(`https://ntfy.sh/${encodeURIComponent(topic)}`, {
    method: "POST",
    headers: { Title: "Download finished" },
    body: download.name,
  });
  if (!response.ok) {
    return { status: "skipped", summary: `ntfy didn't take the message (status ${response.status})` };
  }
  return { status: "passed", summary: `Sent to your ntfy topic “${topic}”` };
}
