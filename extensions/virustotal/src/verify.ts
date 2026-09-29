import { VerifyResult, fetch } from "@orbtorrent/api";

/** The EICAR test file, which every antivirus engine knows. */
const knownFile = "275a021bbfb6489e54d471899f7db9d1663fc695ec2fe2a2c4538aabf651fd0f";

export default async function verify(preferences: OrbPreferences): Promise<VerifyResult> {
  const key = preferences.apiKey.trim();
  if (!key) return { ok: false, message: "Enter your API key." };
  const response = await fetch(`https://www.virustotal.com/api/v3/files/${knownFile}`, {
    headers: { "x-apikey": key, accept: "application/json" },
  });
  switch (response.status) {
    case 200:
      return { ok: true, message: "The key works." };
    case 401:
    case 403:
      return { ok: false, message: "VirusTotal didn't accept this key. Copy it again from your VirusTotal profile." };
    case 429:
      return { ok: true, message: "The key works, but it has reached VirusTotal's limit for now." };
    default:
      return { ok: false, message: `VirusTotal answered with status ${response.status}. Try again in a moment.` };
  }
}
