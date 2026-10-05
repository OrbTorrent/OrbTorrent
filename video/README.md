# The launch film

A 57-second film of OrbTorrent, at 60 frames a second, made from code: each
frame is drawn in Chrome from a timeline, so it renders exactly the same every
time. The orb is the website's own WebGL orb (`website/src/scripts/orb/`), the
same shader as the app's. The film is cut to its music, and the soundtrack is
mixed in the browser too, so every sound lands on its frame.

```sh
npm install
npm run preview                    # play and scrub it, with sound, in a browser
npm run render                     # out/orbtorrent-launch.mp4, 1920 × 1080
node render.mjs --scale 2          # out/orbtorrent-launch-4k.mp4, 3840 × 2160
node render.mjs --theme light      # out/orbtorrent-launch-light.mp4, on the website's paper
node render.mjs --stills 2,4.5     # single frames at those seconds, in out/stills/
npm run check                      # type-check
```

It needs Google Chrome and ffmpeg. A render takes about six minutes in
1080p.

## On the website

The homepage's "Watch the film" plays the light film from
`website/public/film/` (`website/src/components/Film.astro`). That copy is
made from the 4K render, and kept under the site's 25 MiB a file:

```sh
node render.mjs --scale 2 --theme light
ffmpeg -i out/orbtorrent-launch-4k-light.mp4 -vf scale=1920:1080:flags=lanczos \
  -c:v libx264 -preset veryslow -tune animation -crf 18 -profile:v high -level 4.2 \
  -pix_fmt yuv420p -c:a aac -b:a 160k -movflags +faststart \
  ../website/public/film/orbtorrent-2.mp4
```

Give a new cut a new name, and set it as `film.src` in
`website/src/lib/site.ts`: browsers keep the old one for a day. The picture
search engines show for it, `website/src/assets/film/poster.jpg`, is the
opening title, `node render.mjs --theme light --stills 5.8`.

## The music

The music is "This Minimal Technology" by Coma-Media, from Pixabay, under the
[Pixabay Content License](https://pixabay.com/service/license-summary/): free
to use and edit, without credit. It's registered with YouTube's Content ID, so
a YouTube upload may get an automatic claim. That isn't a strike: dispute it
with the track's Pixabay licence certificate
([how](https://pixabay.com/blog/posts/how-to-clear-a-youtube-content-id-claim-with-a-pix-190/)).

The sound effects are from Mixkit, under its
[Sound Effects Free License](https://mixkit.co/license/#sfxFree): free in
videos, without credit.

Neither licence allows sharing the files on their own, so they aren't in the
repository: `render.mjs` downloads them into `audio/` the first time, from the
list in `src/sounds.json`.

## How it's put together

- **`src/cues.ts`** is the timeline, in seconds, at the music's 135 beats a
  minute, and the edit: which of the track's bars plays under each of the
  film's. The pictures and the soundtrack both read it.
- **`src/scenes/`** has one file a scene, each building its own elements and
  moving them as a pure function of time:
  1. The orb comes to light as in an eclipse, a crescent growing until it
     lights up, then its name and the site's tagline.
  2. The orb lands in the menu bar, and its panel drops down. Open App opens
     the library window, as in the press shot, and a download is looked
     inside.
  3. A magnet link decodes, is clicked, and pours into the orb.
  4. The VPN drops and so does the music, to the quiet of its intro: the
     tunnel snaps, everything turns amber, and the groove is back with the
     VPN.
  5. A film's name is checked and found to end in `.exe`, and the download is
     held.
  6. The held card turns over into an extension's code, and a download travels
     the extension pipeline as the music builds.
  7. The orb turns green and shares back as the groove opens again, then five
     words.
  8. The site's headline, with the orb as the o of "torrent", as the music
     ends.
- **`src/looks.ts`** says how full, lively and what colour the orb is through
  the film. The colours mean what they mean in the app.
- **`src/theme.ts`** switches the film to the light theme, on the website's
  paper and ink. The app's own panel, window and cards stay in dark mode, as
  in its screenshots.
- **`src/audio.ts`** cuts the music to the film, places the sound effects,
  and muffles the music while the VPN is down. `render.mjs` brings the mix to
  -14 LUFS.
- **`render.mjs`** builds the film, serves it, captures each frame in headless
  Chrome and pipes them to ffmpeg.

The words come from the website, and each fact in them is checked against it.
The torrents shown are legal: Ubuntu, Fedora, Raspberry Pi OS and Blender's
Big Buck Bunny. "Ocean Life" is the made-up fake from the app's own
screenshots.
