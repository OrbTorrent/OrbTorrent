// The anonymous counts OrbTorrent adds to its update check, in the feed's
// address: see AnonymousCounts.swift in the app. Only these keys are kept,
// and only values of the shape the app sends, so nothing else can be stored
// through them. In the order they're stored, after the app, version and build.

const shapes: [key: string, shape: RegExp][] = [
	["check", /^(daily|manual)$/],
	["macos", /^\d{1,3}\.\d{1,3}$/],
	["chip", /^(apple|intel)$/],
	["installed", /^\d{4}-W\d{2}$/],
	["new", /^[01]$/],
	["week", /^[01]$/],
	["month", /^[01]$/],
];

/** The counts in a check's address, in their fixed order, each "" when missing. */
export function blobs(params: URLSearchParams): string[] {
	return shapes.map(([key, shape]) => {
		const value = params.get(key) ?? "";
		return shape.test(value) ? value : "";
	});
}

/** Unexpected quits of the app and of its engine, since the last check. */
export function doubles(params: URLSearchParams): number[] {
	return ["quits", "engineStops"].map((key) => {
		const value = params.get(key) ?? "";
		return /^\d{1,2}$/.test(value) ? Number(value) : 0;
	});
}
