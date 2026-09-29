import { bindings, defineConfig } from "cf/config";
import * as entrypoint from "./src/index.ts" with { type: "cf-worker" };

// updates.orbtorrent.com, where every installed OrbTorrent looks for updates.
// Deploy with `npm run deploy`; publish a release to it with
// scripts/publish-update.sh.
export default defineConfig({
	worker: {
		name: "orbtorrent-updates",
		compatibilityDate: "2026-09-25",
		entrypoint,
		domains: ["updates.orbtorrent.com"],
		env: {
			// The signed feeds, by name, put there by scripts/publish-update.sh.
			FEEDS: bindings.kv({ id: "0cefcfed2afa4401925f69c2e74ced24" }),
			// Update checks, counted by version.
			CHECKS: bindings.analyticsEngineDataset({ name: "orbtorrent_update_checks" }),
		},
	},
});
