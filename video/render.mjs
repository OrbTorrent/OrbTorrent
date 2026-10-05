// Builds the film and renders it with headless Chrome, one frame at a time,
// into an MP4 with its soundtrack.
//
//   node render.mjs                  the whole film, to out/orbtorrent-launch.mp4
//   node render.mjs --scale 2        the same in 4K
//   node render.mjs --stills 2,4.5   single frames at those seconds, to out/stills/
//   node render.mjs --preview        serve it, to play and scrub in a browser
//   --theme light                    on the website's paper instead of night

import { build } from "esbuild";
import { createServer } from "node:http";
import { createReadStream, existsSync, mkdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright";

const here = fileURLToPath(new URL(".", import.meta.url));
const args = process.argv.slice(2);
const option = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? fallback : args[i + 1];
};
const scale = Number(option("scale", 1));
const out = join(here, "out");
mkdirSync(out, { recursive: true });

// The music and sound effects, from Mixkit, downloaded the first time. The
// music comes as an MP3 and is decoded once with ffmpeg, so its beats sit
// exactly where cues.ts expects them.
const sounds = JSON.parse(readFileSync(join(here, "src/sounds.json"), "utf8"));
const audioDir = join(here, "audio");
mkdirSync(join(audioDir, "sfx"), { recursive: true });
const download = async (url, file) => {
  const response = await fetch(url, { headers: { "user-agent": "Mozilla/5.0" } });
  if (!response.ok) throw new Error(`Couldn't download ${url}: ${response.status}`);
  writeFileSync(file, Buffer.from(await response.arrayBuffer()));
};
const musicFile = join(audioDir, sounds.music.file);
if (!existsSync(musicFile)) {
  console.log(`Downloading "${sounds.music.title}"…`);
  const mp3 = join(audioDir, "music.mp3");
  await download(sounds.music.url, mp3);
  const decoded = spawnSync("ffmpeg", ["-y", "-loglevel", "error", "-i", mp3, "-c:a", "pcm_s16le", musicFile], { stdio: "inherit" });
  if (decoded.status !== 0) throw new Error("ffmpeg couldn't decode the music");
}
for (const id of Object.values(sounds.effects)) {
  const file = join(audioDir, "sfx", `${id}.wav`);
  if (!existsSync(file)) await download(`https://assets.mixkit.co/active_storage/sfx/${id}/${id}.wav`, file);
}

await build({
  entryPoints: [join(here, "src/main.ts")],
  bundle: true,
  format: "esm",
  target: "chrome120",
  outfile: join(here, "dist/main.js"),
  logLevel: "warning",
});

// Serves the film, the site's public files and the Mac's mono font.
const roots = [
  ["/site/", join(here, "../website/public/")],
  ["/fonts/SFNSMono.ttf", "/System/Library/Fonts/SFNSMono.ttf"],
  ["/", here],
];
const types = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css", ".woff2": "font/woff2", ".ttf": "font/ttf", ".webp": "image/webp", ".png": "image/png", ".wav": "audio/wav" };
const server = createServer((req, res) => {
  const url = decodeURIComponent(new URL(req.url, "http://x").pathname);
  const path = url === "/" ? join(here, "src/index.html") : (() => {
    for (const [prefix, dir] of roots) if (url.startsWith(prefix)) return normalize(join(dir, url.slice(prefix.length)));
  })();
  if (!path || !existsSync(path) || statSync(path).isDirectory()) {
    res.writeHead(404).end();
    return;
  }
  res.writeHead(200, { "content-type": types[extname(path)] ?? "application/octet-stream", "cache-control": "no-store" });
  createReadStream(path).pipe(res);
});
const port = Number(option("port", 8791));
await new Promise((r) => server.listen(port, "127.0.0.1", r));
const address = `http://127.0.0.1:${port}/`;

if (args.includes("--preview")) {
  console.log(`Preview: ${address}?preview  (space plays, arrows step, shift-arrows jump a second)`);
} else {
  const browser = await chromium.launch({
    channel: "chrome",
    headless: true,
    // Playwright's own scale factor doesn't reach headless Chrome here, so the flag sets it.
    args: ["--enable-gpu", "--ignore-gpu-blocklist", "--use-angle=metal", "--hide-scrollbars", "--force-color-profile=srgb", "--autoplay-policy=no-user-gesture-required", `--force-device-scale-factor=${scale}`],
  });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: scale });
  page.on("console", (m) => m.type() === "error" && console.error("page:", m.text()));
  page.on("pageerror", (e) => console.error("page error:", e.message));
  const theme = option("theme");
  await page.goto(theme ? `${address}?theme=${theme}` : address);
  await page.waitForFunction(() => window.film);
  await page.evaluate(() => window.film.ready());
  const client = await page.context().newCDPSession(page);
  const frames = await page.evaluate(() => window.film.frames);
  const fps = await page.evaluate(() => window.film.fps);
  const grab = async () => {
    const { data } = await client.send("Page.captureScreenshot", { format: "png", optimizeForSpeed: true, clip: { x: 0, y: 0, width: 1920, height: 1080, scale: 1 } });
    return Buffer.from(data, "base64");
  };

  const stills = option("stills");
  if (stills) {
    mkdirSync(join(out, "stills"), { recursive: true });
    for (const s of stills.split(",")) {
      const frame = Math.round(Number(s) * fps);
      // Some looks build up over time, so play up to the frame from a second before.
      for (let f = Math.max(0, frame - 2); f <= frame; f++) await page.evaluate((f) => window.film.seek(f), f);
      const file = join(out, "stills", `t${Number(s).toFixed(2).padStart(5, "0")}.png`);
      writeFileSync(file, await grab());
      console.log(file);
    }
  } else {
    const from = Number(option("from", 0));
    const to = Number(option("to", frames / fps));
    const name = option("name", `orbtorrent-launch${scale > 1 ? "-4k" : ""}${theme ? `-${theme}` : ""}`);

    console.log("Rendering the soundtrack…");
    const audio = await page.evaluate(() => window.film.audio());
    const wavFile = join(out, `${name}.wav`);
    writeFileSync(wavFile, Buffer.from(audio, "base64"));
    // Brought to -14 LUFS, the loudness YouTube and others play at, with a
    // limiter keeping the peaks under -1.5 dB once encoded.
    const meter = spawnSync("ffmpeg", ["-hide_banner", "-i", wavFile, "-af", "ebur128", "-f", "null", "-"], { encoding: "utf8" });
    const loudness = Number(meter.stderr.match(/I:\s+(-?[\d.]+) LUFS/g)?.pop()?.match(/-?[\d.]+/)?.[0]);
    const volume = Number.isFinite(loudness) ? -14 - loudness : 0;
    console.log(`Soundtrack: ${loudness.toFixed(1)} LUFS, ${volume.toFixed(1)} dB to -14`);

    const mp4 = join(out, `${name}.mp4`);
    const ffmpeg = spawn("ffmpeg", [
      "-y", "-loglevel", "error",
      "-f", "image2pipe", "-framerate", String(fps), "-c:v", "png", "-i", "-",
      "-ss", String(from), "-i", wavFile,
      "-vf", "scale=out_color_matrix=bt709:out_range=tv,format=yuv420p",
      "-af", `volume=${volume.toFixed(2)}dB,alimiter=limit=0.75:level=false`,
      "-c:v", "libx264", "-preset", "slow", "-crf", scale > 1 ? "16" : "14", "-tune", "film",
      "-profile:v", "high", "-level", scale > 1 ? "5.2" : "4.2",
      "-color_primaries", "bt709", "-color_trc", "bt709", "-colorspace", "bt709", "-color_range", "tv",
      "-c:a", "aac", "-b:a", "320k", "-ar", "48000",
      "-shortest", "-movflags", "+faststart", mp4,
    ], { stdio: ["pipe", "inherit", "inherit"] });
    const done = new Promise((r, j) => ffmpeg.on("close", (code) => (code === 0 ? r() : j(new Error(`ffmpeg exited ${code}`)))));

    const first = Math.round(from * fps);
    const last = Math.round(to * fps);
    const started = Date.now();
    for (let f = first; f < last; f++) {
      await page.evaluate((f) => window.film.seek(f), f);
      const png = await grab();
      if (!ffmpeg.stdin.write(png)) await new Promise((r) => ffmpeg.stdin.once("drain", r));
      if (f % 60 === 0) process.stdout.write(`\rFrame ${f}/${last} · ${((Date.now() - started) / 1000).toFixed(0)}s`);
    }
    ffmpeg.stdin.end();
    await done;
    rmSync(wavFile);
    console.log(`\n${mp4}`);
  }
  await browser.close();
  server.close();
}
