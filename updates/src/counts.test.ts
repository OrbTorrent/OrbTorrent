import assert from "node:assert/strict";
import { test } from "node:test";
import { blobs, doubles } from "./counts.ts";

test("keeps the counts the app sends, in order", () => {
	const params = new URLSearchParams(
		"check=daily&macos=26.1&chip=apple&installed=2026-W40&new=1&week=1&month=0&quits=2&engineStops=0",
	);
	assert.deepEqual(blobs(params), ["daily", "26.1", "apple", "2026-W40", "1", "1", "0"]);
	assert.deepEqual(doubles(params), [2, 0]);
});

test("an older app's check, with no counts, is stored blank", () => {
	assert.deepEqual(new Set(blobs(new URLSearchParams(""))), new Set([""]));
	assert.deepEqual(doubles(new URLSearchParams("")), [0, 0]);
});

test("anything else is dropped", () => {
	const params = new URLSearchParams(
		"macos=<script>&chip=arm&installed=last-week&new=yes&quits=-1&engineStops=1e9&email=someone@example.com",
	);
	assert.ok(blobs(params).every((value) => value === ""));
	assert.deepEqual(doubles(params), [0, 0]);
});
