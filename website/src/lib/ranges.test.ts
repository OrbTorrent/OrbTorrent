// The film's byte ranges, as Safari asks for them.
import assert from "node:assert/strict";
import { test } from "node:test";
import { parseRange, withRange } from "./ranges.ts";

const size = 100;
const file = Uint8Array.from({ length: size }, (_, i) => i);
const etag = '"film-1"';

/**
 * The file as the static assets give it: whole, streamed in uneven chunks,
 * and inside the Worker without its size.
 */
function asset(status = 200, sized = true): Response {
  let at = 0;
  const body = new ReadableStream<Uint8Array>({
    pull(controller) {
      if (at >= size) return controller.close();
      const next = Math.min(at + 7, size);
      controller.enqueue(file.slice(at, next));
      at = next;
    },
  });
  return new Response(status === 304 ? null : body, {
    status,
    headers: { "Content-Type": "video/mp4", ETag: etag, ...(sized ? { "Content-Length": String(size) } : {}) },
  });
}

function request(headers: Record<string, string> = {}, method = "GET"): Request {
  return new Request("https://orbtorrent.com/film/orbtorrent.mp4", { method, headers });
}

async function bytes(response: Response): Promise<number[]> {
  return [...new Uint8Array(await response.arrayBuffer())];
}

const range = (start: number, end: number) => [...file.slice(start, end + 1)];

test("without a Range, the whole file, saying ranges are welcome", async () => {
  const response = withRange(request(), asset());
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Accept-Ranges"), "bytes");
  assert.equal(response.headers.get("Content-Type"), "video/mp4");
  assert.deepEqual(await bytes(response), [...file]);
});

test("Safari's first question, the first two bytes", async () => {
  const response = withRange(request({ Range: "bytes=0-1" }), asset());
  assert.equal(response.status, 206);
  assert.equal(response.headers.get("Content-Range"), "bytes 0-1/100");
  assert.equal(response.headers.get("Content-Length"), "2");
  assert.equal(response.headers.get("ETag"), etag);
  assert.deepEqual(await bytes(response), [0, 1]);
});

test("a range across several chunks", async () => {
  const response = withRange(request({ Range: "bytes=5-40" }), asset());
  assert.equal(response.headers.get("Content-Range"), "bytes 5-40/100");
  assert.deepEqual(await bytes(response), range(5, 40));
});

test("from a byte to the end", async () => {
  const response = withRange(request({ Range: "bytes=93-" }), asset());
  assert.equal(response.headers.get("Content-Range"), "bytes 93-99/100");
  assert.deepEqual(await bytes(response), range(93, 99));
});

test("the last bytes", async () => {
  const response = withRange(request({ Range: "bytes=-10" }), asset());
  assert.equal(response.headers.get("Content-Range"), "bytes 90-99/100");
  assert.deepEqual(await bytes(response), range(90, 99));
});

test("an end past the file stops at its end", async () => {
  const response = withRange(request({ Range: "bytes=50-5000" }), asset());
  assert.equal(response.headers.get("Content-Range"), "bytes 50-99/100");
  assert.deepEqual(await bytes(response), range(50, 99));
});

test("a start past the file is 416", async () => {
  const response = withRange(request({ Range: "bytes=100-" }), asset());
  assert.equal(response.status, 416);
  assert.equal(response.headers.get("Content-Range"), "bytes */100");
  assert.deepEqual(await bytes(response), []);
});

test("several ranges, other units and nonsense get the whole file", async () => {
  for (const value of ["bytes=0-1,5-6", "items=0-1", "bytes=9-2", "bytes=-", "bytes=a-b"]) {
    const response = withRange(request({ Range: value }), asset());
    assert.equal(response.status, 200, value);
    assert.deepEqual(await bytes(response), [...file], value);
  }
});

test("If-Range: the bytes only while the file is the same", async () => {
  const same = withRange(request({ Range: "bytes=0-1", "If-Range": etag }), asset());
  assert.equal(same.status, 206);
  const changed = withRange(request({ Range: "bytes=0-1", "If-Range": '"film-0"' }), asset());
  assert.equal(changed.status, 200);
  assert.deepEqual(await bytes(changed), [...file]);
});

test("a HEAD request gets the headers alone", async () => {
  const response = withRange(request({ Range: "bytes=0-1" }, "HEAD"), asset());
  assert.equal(response.status, 206);
  assert.equal(response.headers.get("Content-Length"), "2");
  assert.equal(response.body, null);
});

test("from the start to the end, as Chrome asks, the whole file as a range", async () => {
  const response = withRange(request({ Range: "bytes=0-" }), asset());
  assert.equal(response.status, 206);
  assert.equal(response.headers.get("Content-Range"), "bytes 0-99/100");
  assert.deepEqual(await bytes(response), [...file]);
});

test("a range that starts on a chunk's edge", async () => {
  const response = withRange(request({ Range: "bytes=14-" }), asset());
  assert.deepEqual(await bytes(response), range(14, 99));
  const inside = withRange(request({ Range: "bytes=14-20" }), asset());
  assert.deepEqual(await bytes(inside), range(14, 20));
});

test("the size from /film/sizes.json, when the response doesn't say", async () => {
  const response = withRange(request({ Range: "bytes=5-9" }), asset(200, false), size);
  assert.equal(response.status, 206);
  assert.equal(response.headers.get("Content-Range"), "bytes 5-9/100");
  assert.deepEqual(await bytes(response), range(5, 9));
});

test("a file of unknown size is sent whole", async () => {
  const response = withRange(request({ Range: "bytes=5-9" }), asset(200, false), undefined);
  assert.equal(response.status, 200);
  assert.deepEqual(await bytes(response), [...file]);
});

test("anything but the file itself passes through", () => {
  const response = withRange(request({ Range: "bytes=0-1" }), asset(304));
  assert.equal(response.status, 304);
});

test("parseRange", () => {
  assert.deepEqual(parseRange("bytes=0-0", 1), [0, 0]);
  assert.deepEqual(parseRange(" bytes=3-3 ", 10), [3, 3]);
  assert.equal(parseRange("bytes=-0", 10), "past the end");
  assert.deepEqual(parseRange("bytes=-50", 10), [0, 9]);
  assert.equal(parseRange("bytes=99999999999999999999-", 10), "past the end");
});
