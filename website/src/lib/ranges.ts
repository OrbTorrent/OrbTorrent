// Workers' static assets answer every request with the whole file. Safari, and
// so every browser on an iPhone, plays a video only from a server that answers
// a Range request with just the bytes it asked for, so the Worker answers those
// for the film (src/worker.ts). The file's response doesn't say how big it is,
// so the Worker reads that from /film/sizes.json, made with the site.

/** The Workers runtime's stream that gives a streamed response its Content-Length. */
type FixedLength = new (length: number) => TransformStream<Uint8Array, Uint8Array>;

/**
 * The file's response, answering the request's Range if it has one: 206 with
 * those bytes, or 416 when they start past the end. Anything else, such as
 * several ranges at once, or a file of unknown size, gets the whole file,
 * which is always a correct answer.
 */
export function withRange(request: Request, response: Response, size = Number(response.headers.get("Content-Length"))): Response {
  const headers = new Headers(response.headers);
  headers.set("Accept-Ranges", "bytes");
  const whole = () => new Response(response.body, { status: response.status, statusText: response.statusText, headers });

  const range = request.headers.get("Range");
  if (response.status !== 200 || !range || !Number.isSafeInteger(size) || size <= 0) return whole();
  // If-Range asks for the bytes only if the file is still the one it had.
  const ifRange = request.headers.get("If-Range");
  if (ifRange && ifRange !== response.headers.get("ETag")) return whole();

  const bytes = parseRange(range, size);
  if (bytes === null) return whole();
  if (bytes === "past the end") {
    void response.body?.cancel();
    headers.set("Content-Range", `bytes */${size}`);
    headers.set("Content-Length", "0");
    return new Response(null, { status: 416, headers });
  }

  const [start, end] = bytes;
  const length = end - start + 1;
  headers.set("Content-Range", `bytes ${start}-${end}/${size}`);
  headers.set("Content-Length", String(length));
  if (request.method === "HEAD" || !response.body) {
    void response.body?.cancel();
    return new Response(null, { status: 206, headers });
  }
  return new Response(slice(response.body, start, end + 1, size), { status: 206, headers });
}

/**
 * One range, as bytes=start-end, bytes=start- or bytes=-last, with its end
 * kept inside the file. Null for anything else, which is answered with the
 * whole file.
 */
export function parseRange(range: string, size: number): [number, number] | "past the end" | null {
  const match = /^bytes=(\d*)-(\d*)$/.exec(range.trim());
  if (!match || (!match[1] && !match[2])) return null;
  if (!match[1]) {
    const last = Number(match[2]);
    return last > 0 ? [Math.max(0, size - last), size - 1] : "past the end";
  }
  const start = Number(match[1]);
  if (start >= size) return "past the end";
  const end = match[2] ? Math.min(Number(match[2]), size - 1) : size - 1;
  return end >= start ? [start, end] : null;
}

/**
 * The bytes from `from` up to `to` of the file's stream. JavaScript reads only
 * up to the first of them. When they run to the end of the file, as nearly
 * every request from a browser does, the runtime pipes the rest on its own,
 * which costs the Worker almost no CPU time: the free plan allows 10 ms.
 */
function slice(body: ReadableStream<Uint8Array>, from: number, to: number, size: number): ReadableStream<Uint8Array> {
  // Without a known length, the runtime would drop the Content-Length header.
  const Fixed = (globalThis as { FixedLengthStream?: FixedLength }).FixedLengthStream;
  const { readable, writable } = Fixed ? new Fixed(to - from) : new TransformStream<Uint8Array, Uint8Array>();
  void copy(body, writable, from, to, to === size);
  return readable;
}

async function copy(body: ReadableStream<Uint8Array>, writable: WritableStream<Uint8Array>, from: number, to: number, toTheEnd: boolean) {
  const reader = body.getReader();
  const writer = writable.getWriter();
  let at = 0;
  try {
    while (at < to && !(toTheEnd && at >= from)) {
      const { done, value } = await reader.read();
      if (done) break;
      const start = Math.max(from - at, 0);
      const end = Math.min(to - at, value.byteLength);
      at += value.byteLength;
      if (start < end) await writer.write(value.subarray(start, end));
    }
    if (toTheEnd && at >= from && at < to) {
      reader.releaseLock();
      writer.releaseLock();
      await body.pipeTo(writable);
      return;
    }
    await reader.cancel();
    await writer.close();
  } catch (error) {
    // A file that ends early, or a browser that stops listening: the response
    // ends short, which tells the browser.
    await reader.cancel(error).catch(() => {});
    await writer.abort(error).catch(() => {});
  }
}
