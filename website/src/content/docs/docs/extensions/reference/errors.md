---
title: Errors and fixes
description: The error messages orb and OrbTorrent give when building, testing, running and installing an extension, what each means, and how to fix it.
---

Every error says what's wrong, and most say what to do. Here they all are, by where you'll meet them.

## Network

Thrown by `fetch`, in OrbTorrent and in tests alike.

| Message | Fix |
|---|---|
| Request to *host* was refused. Add "*host*" to permissions.network in package.json. | Add that exact host to `permissions.network`. `example.com` doesn't cover `www.example.com`. |
| Request to *address* was refused: extensions can only use https:// addresses. | Use `https://`. |
| Request to *host*:*port* was refused: extensions can only use the standard HTTPS port. | Use port 443, the default for `https://`. |
| Request to *address* was refused: put credentials in a header, not the address. | Move `user:password@` into a header, such as `Authorization`. |
| Request to *host* was refused: it points to *address*, which is on this Mac or your local network. | Extensions can't reach the Mac or local network. Use a service on the internet. |
| *host* couldn't be found. Check the address and your connection. | Check the host name, and that the Mac is online. Before a download starts, return `skipped`. |
| The response was larger than 10 MB, the most an extension can receive. | Ask for less, such as one page of results at a time. |
| The request method "*method*" isn't supported. | Use `GET`, `HEAD`, `POST`, `PUT`, `PATCH` or `DELETE`. |
| A request body must be text, or a form from files.formData(). | Use `JSON.stringify` for JSON. |
| fetch needs an https:// address. | Pass a full address, such as `https://api.example.com/…`. |
| Each form field needs a name. | Give every field in `files.formData` a name. |

## Files

Thrown by `files.sha256` and `files.formData`.

| Message | Fix |
|---|---|
| Reading files isn't allowed. Add "files": "contents" to permissions in package.json. | Add `"files": "contents"` to `permissions`. |
| File *n* isn't available: it isn't downloaded yet, or it isn't part of this download. | Read files only in `afterFinish` hooks, and only files from `download.files`. |
| File *n* is missing: it was moved or deleted after downloading. | The user moved or deleted it. Skip it, and say so in the result. |
| Pass a file from download.files. | Pass a `DownloadFile`, or its `index`. |

## Storage

| Message | Fix |
|---|---|
| Storage is full: an extension can keep up to 1 MB. Remove keys it no longer needs. | Remove old keys, or keep less, such as only recent answers. |
| A storage key must be text of up to 200 characters. | Use a shorter key, such as a hash. |

## A check that didn't finish

Shown in the Checks tab, and by `orb run`.

| Message | Fix |
|---|---|
| Didn't finish: *message* | The hook threw. Its log has the stack trace. |
| Didn't finish: it took longer than 15 s | Before a download starts, do less, or move the work to `afterFinish`. |
| Didn't finish: it kept the processor busy for over 10 s | Do less work in loops. Waiting doesn't count. |
| Didn't finish: it used more than 512 MB of memory | Hold less in memory at once. |
| Didn't finish: It returned something that isn't a result: return { status, summary }. | Return a `status` and a non-empty `summary`. |
| Didn't finish: The extension crashed (signal …). | Its log may say why. If it keeps happening, [report it](/docs/help/report-a-problem). |
| OrbTorrent doesn't know "*method*". Update OrbTorrent, or check the @orbtorrent/api version. | The extension uses a newer API than this OrbTorrent has. Update OrbTorrent. |

## orb build

| Message | Fix |
|---|---|
| package.json isn't valid. | Each problem is listed under it, such as "“name” must be lowercase letters, digits and hyphens". [Manifest](/docs/extensions/reference/manifest) has the rules. |
| Some entry points are missing. | The hook "*name*" needs src/*name*.ts: name the file after the hook, or rename the hook. |
| "*module*" is a Node.js module, and extensions don't run in Node.js. | Use the API the message names, such as `fetch` instead of `https`. |
| TypeScript found problems. | Each is listed with its file, line and column. |
| The extension couldn't be bundled. | Usually a missing package: run `npm install`. |
| ! The icon assets/*icon* doesn't exist, so OrbTorrent shows a plain one. | A warning. Add the icon, or remove `"icon"`. |

## orb test

| Message | Fix |
|---|---|
| The test has no mock for *method* *address*. Add one to "mocks": { "fetch": [...] }. | Add a mock that matches. `*` in its `url` matches any text. |
| The test gives file *n* no "sha256". Add one to its download.files entry. | Add `sha256` to that file in the test. |
| say which hook to run with "hook" | The extension has more than one hook. Name one in the test. |
| the extension has no "verify" in package.json | Add `"verify"`, or remove `"verify": true` from the test. |
| It didn't finish within 10 s. | The hook is waiting on something that never comes, such as a promise that never settles. Or raise `timeout`. |
| There are no tests. | Add a JSON file to `tests/`. |

## Connecting to OrbTorrent

From `orb dev`, `orb run`, `orb downloads` and `orb install`.

| Message | Fix |
|---|---|
| OrbTorrent isn't reachable. | Open OrbTorrent, and turn on **Allow development extensions** on the Develop tab of its Extensions page. `npx orb doctor` says what's missing. |
| You chose not to load it in OrbTorrent. | OrbTorrent asked whether to load the folder, and the answer was no. Run the command again, and allow it. |
| OrbTorrent couldn't load it. | The built manifest isn't valid: the problems are listed. Run `npx orb build`. |
| No download matches "*name*". Your downloads: | Use part of one of the names listed, or `npx orb downloads`. |
| "*name*" matches 3 downloads. Use one of these names or info hashes: | Use more of the name, or the info hash. |
| "*name*" hasn't finished downloading, so its files aren't all there. Choose a finished download. | An `afterFinish` hook needs a finished download. |
| The user chose not to install it. | The install was cancelled in OrbTorrent. |
| OrbTorrent closed the connection. | OrbTorrent quit, or development extensions were turned off. |

## Before it runs

Shown on the Extensions page.

| It says | Fix |
|---|---|
| Needs setup | A required setting is empty. Its hooks are skipped until it's filled in. |
| Needs a newer OrbTorrent | It was built with a newer `@orbtorrent/api` than this OrbTorrent supports. Update OrbTorrent, or build with the API version `orb doctor` reports. |
| "*folder*" couldn't be loaded | The extension's `package.json` isn't valid. Its page lists why. |
