import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

/** The @orbtorrent/api package folder: dist/cli is two levels down. */
export const sdkRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

/** The API version extensions built with this package use. */
export const sdkVersion: string = JSON.parse(readFileSync(join(sdkRoot, "package.json"), "utf8")).version;
