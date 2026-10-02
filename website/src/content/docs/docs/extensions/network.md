---
title: Network requests
description: Reach a web service from an extension with fetch, list the hosts it needs, and handle errors, rate limits and redirects.
---

Extensions have no network of their own. They reach the web through `fetch` from `@orbtorrent/api`, and only the hosts they list.

## List the hosts

Add each host the extension talks to in `package.json`:

```json title="package.json"
{
  "permissions": {
    "network": ["www.virustotal.com"]
  }
}
```

- **Exact host names,** in lowercase, without `https://` or a path. `virustotal.com` doesn't cover `www.virustotal.com`: list each one you use. There are no wildcards.
- **Users see the list** on the extension's page and before they install it, as "Connect to www.virustotal.com". Ask only for what you need.

## Make a request

```ts title="src/notify.ts"
import { Download, Result, fetch, getPreferenceValues } from "@orbtorrent/api";

export default async function notify(download: Download): Promise<Result> {
  const { webhook } = getPreferenceValues();
  const response = await fetch(webhook, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ content: `Finished: ${download.name}` }),
  });
  if (!response.ok) {
    return { status: "skipped", summary: `Discord didn't take the message (status ${response.status})` };
  }
  return { status: "passed", summary: "Sent to your Discord channel" };
}
```

This needs `"network": ["discord.com"]`, and a `webhook` setting for the channel's webhook address.

### The request

`fetch(url, init?)` takes an address, as a string or a `URL`, and:

| | |
|---|---|
| `method` | `GET`, `HEAD`, `POST`, `PUT`, `PATCH` or `DELETE`. `GET` unless you say. |
| `headers` | An object, such as `{ "x-apikey": key }`. OrbTorrent sets `host`, `content-length`, `connection` and `transfer-encoding` itself, and drops `cookie`. |
| `body` | Text, using `JSON.stringify` for JSON, or a form from [`files.formData`](/docs/extensions/files#upload-a-file). |

### The response

| | |
|---|---|
| `status` | The HTTP status, such as `200`. |
| `ok` | Whether the status is 200 to 299. |
| `url` | The address it came from, after any redirects. |
| `headers` | `get(name)`, `has(name)` and `entries()`. Names are case-insensitive. |
| `text()` | The body as text. |
| `json()` | The body parsed as JSON. |

The body is read as UTF-8 text, so `fetch` suits JSON and text APIs, not downloading binary files.

## The rules

OrbTorrent checks every request before it's made:

- **HTTPS only,** on the standard port, 443.
- **Only listed hosts.** A request to any other is refused with an error that says which host to add.
- **Never your Mac or your network.** A host that points to an address on the Mac or the local network is refused, wherever its name says it is.
- **Redirects only to listed hosts.** A redirect to any other host isn't followed: the hook gets the redirect response itself.
- **No credentials in the address.** Put them in a header instead.
- **Responses up to 10 MB,** and **30 seconds** for each request.
- **No cookies and no shared cache,** so one extension can't see another's sessions.

A refused request, or one that fails, throws an error. [Errors and fixes](/docs/extensions/reference/errors#network) lists the messages.

## Handle failure

The network can always fail, so decide what that means for your check:

```ts
let response;
try {
  response = await fetch(`https://api.example.com/check/${download.id}`);
} catch (error) {
  // Before a download starts, a network error means skipped, never failed.
  return { status: "skipped", summary: `Couldn't reach example.com: ${(error as Error).message}` };
}
```

**Before a download starts, a network error or a timeout means `skipped`, never `failed`.** A `beforeStart` hook has 15 seconds in all, so keep its requests few and quick.

## Respect rate limits

Many free APIs allow only so many requests a minute. To stay within them:

- **Wait between requests** with [`sleep`](/docs/extensions/reference/api#sleep), which doesn't use CPU time. An `afterFinish` hook has 6 hours, so it can pace itself.
- **Show progress** on long runs with [`progress`](/docs/extensions/storage#show-progress), so the user sees it working.
- **Keep answers** in [`storage`](/docs/extensions/storage), so running the hook again doesn't ask again.
- **Back off on 429.** Wait, try once more, and if it's refused again, return `skipped` with what happened.

Each extension's `afterFinish` runs go one at a time, so a hook never competes with itself for a rate limit.

## Test it

Tests answer requests from mocks, so they run without the network. [Testing](/docs/extensions/testing#mock-the-network) explains.

```json title="tests/sends-the-name.json"
{
  "preferences": { "webhook": "https://discord.com/api/webhooks/123/abc" },
  "download": { "name": "Ubuntu 26.04", "files": [{ "path": "ubuntu-26.04.iso", "size": 6000000000 }] },
  "mocks": { "fetch": [{ "method": "POST", "url": "https://discord.com/api/webhooks/*", "status": 204 }] },
  "expect": { "status": "passed", "fetched": ["https://discord.com/api/webhooks/123/abc"] }
}
```
