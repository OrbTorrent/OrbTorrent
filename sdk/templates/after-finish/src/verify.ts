import { VerifyResult } from "@orbtorrent/api";

/** Runs when the user presses Verify in the extension's settings. */
export default async function verify(preferences: OrbPreferences): Promise<VerifyResult> {
  if (!/^[A-Za-z0-9_-]{1,64}$/.test(preferences.topic)) {
    return { ok: false, message: "A topic can only use letters, digits, hyphens and underscores." };
  }
  return { ok: true, message: "Subscribe to this topic in the ntfy app to get the notifications." };
}
