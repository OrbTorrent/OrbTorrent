import { Download, DownloadFile, FileResult, Result } from "@orbtorrent/api";

// Looks at the names and sizes of a download's files, before any of it
// downloads, for the signs fakes share. Everything here is local: it sends
// nothing anywhere.
//
// It first works out what a download is: a video, music or a book from what
// most of its size is, and otherwise from its name, since a fake film often
// has no video at all. Films, music and books never need a program, but
// software, games and courses do, so programs only count in the first three.

const videos = new Set(["mkv", "mp4", "avi", "mov", "wmv", "asf", "m4v", "mpg", "mpeg", "webm", "flv", "ts", "m2ts", "vob", "3gp", "ogv", "rmvb", "divx"]);
const songs = new Set(["mp3", "flac", "m4a", "m4b", "aac", "ogg", "opus", "wav", "aiff", "aif", "alac", "ape", "wv", "dsf", "dff", "wma"]);
const books = new Set(["epub", "mobi", "azw", "azw3", "pdf", "djvu", "fb2", "cbz", "cbr", "cb7"]);
const pictures = new Set(["jpg", "jpeg", "png", "gif", "webp", "heic", "bmp", "tif", "tiff"]);
/** Windows programs, scripts and shortcuts, which run when opened. */
const windowsPrograms = new Set(["exe", "scr", "com", "pif", "bat", "cmd", "msi", "msp", "msix", "appx", "lnk", "vbs", "vbe", "js", "jse", "wsf", "wsh", "ps1", "hta", "cpl", "scf", "reg", "jar", "msc", "gadget", "application", "appref-ms"]);
/** Of those, the scripts: code to read, in a course or next to other code. */
const scripts = new Set(["bat", "cmd", "vbs", "vbe", "js", "jse", "wsf", "wsh", "ps1", "reg", "jar"]);
/** Mac programs, scripts and installers that are files. */
const macPrograms = new Set(["dmg", "pkg", "mpkg", "command", "tool", "terminal", "scpt", "applescript"]);
/** Mac programs that are folders, such as "Player.app/Contents/MacOS/Player". */
const macBundles = new Set(["app", "saver", "prefpane", "workflow", "action", "scptd", "pkg", "mpkg", "qlgenerator", "osax"]);
/** Source code, which says the scripts beside it are code too. */
const code = new Set(["css", "scss", "jsx", "tsx", "vue", "svelte", "py", "ipynb", "java", "kt", "c", "h", "cpp", "cs", "go", "rs", "rb", "php", "swift", "sql", "sh", "psm1", "psd1", "yml", "yaml"]);
const archives = new Set(["rar", "zip", "7z", "tar", "gz", "tgz", "bz2", "xz"]);
const links = new Set(["url", "webloc", "html", "htm"]);
/** What a program pretends to be, by the extension it hides behind. */
const disguises: Record<string, string> = {
  ...Object.fromEntries([...videos].map((extension) => [extension, "video"])),
  ...Object.fromEntries([...pictures].map((extension) => [extension, "picture"])),
  ...Object.fromEntries([...songs].map((extension) => [extension, "song"])),
  ...Object.fromEntries([...books].map((extension) => [extension, "book"])),
  ...Object.fromEntries(["pdf", "txt", "nfo", "doc", "docx", "rtf"].map((extension) => [extension, "document"])),
  ...Object.fromEntries(["srt", "sub", "ass", "ssa", "idx", "vtt"].map((extension) => [extension, "subtitle"])),
};

// Patterns for names. Most run on `words(name)`: lowercase, with every run of
// punctuation turned into one space, so "WEB-DL", "Web.DL" and "web dl" match alike.
const resolution = /\b(2160p|1080p|1080i|720p|576p|480p)\b/;
const sourceOrCodec = /\b(web ?dl|web ?rip|blu ?ray|bd ?rip|br ?rip|remux|dvd ?rip|dvd ?scr|hdtv|hd ?rip|hd ?cam|cam ?rip|hd ?ts|hd ?tc|tele ?sync|x ?26[45]|h ?26[45])\b/;
const quality = /\b(2160p|1080p|1080i|720p|576p|480p|4k|uhd|hdr|hdr10|web ?dl|web ?rip|blu ?ray|bd ?rip|br ?rip|remux|dvd ?rip|dvd ?scr|hdtv|hd ?rip|hd ?cam|cam ?rip|hd ?ts|hd ?tc|tele ?sync|x ?26[45]|h ?26[45]|hevc|xvid|divx)\b/;
const filmWords = /\b(full movie|movie|film|full hd|hd|dual audio|dubbed|extended|directors cut|unrated|imax)\b/;
const episodeMarker = /\b(s\d{1,2} ?e\d{1,3}|s\d{1,2}|season ?\d{1,2}|\d{1,2}x\d{2}|e\d{2,3}|ep ?\d{1,3}|episode ?\d{1,4}|complete series)\b/;
/** An anime episode, such as "[Group] Title - 28 (1080p)". Runs on the name itself. */
const animeEpisode = /\s-\s(?!(?:19|20)\d\d(?!\d))\d{1,4}(?:v\d)?(?=$|[\s.[(])/;
/** A year in brackets, as in "Title (2024)". Runs on the name itself. */
const bracketYear = /[([](?:19|20)\d\d[)\]]/;
/** Names that aren't a whole film, though they're video. */
const notAFilm = /\b(sample|trailer|teaser|preview|promo|featurette|clip|music video|official video|lyric video|official audio|short film)\b/;
/** Folders and files that come with a film but aren't it. */
const extras = /\b(sample|samples|trailer|trailers|teaser|featurettes?|extras|bonus|behind the scenes|deleted scenes|promo)\b/;
const courseWords = /\b(udemy|coursera|pluralsight|lynda|skillshare|domestika|egghead|linkedin learning|frontend masters|masterclass|bootcamp|course|courses|tutorial|tutorials|lectures)\b/;
const softwareWords = /\b(for (mac|macos|windows|win|pc|linux)|macos|mac os|osx|os x|windows|win ?(32|64|7|8|10|11)|x64|x86|amd64|arm64|apple silicon|universal|portable|multilingual|pre ?activated|activated|cracked|crack|keygen|serial|patch|installer|setup|retail|r2r|tnt|gog|fitgirl|dodi|elamigos|steamrip|xatab|codex|skidrow|plaza|empress|tenoke|razor1911|pc)\b/;
/** A version number, such as "v2.3" or "1.10.2". Runs on the name itself. */
const version = /(?:^|[\s_([.-])v\d+(?:\.\d+)+(?=$|[\s_.)\]-])|(?:^|[\s_([-])v?\d+\.\d+\.\d+/i;
/** Music and books, whose names have years too. */
const otherMedia = /\b(flac|mp3|aac|alac|kbps|lossless|vinyl|discography|album|ost|soundtrack|epub|mobi|pdf|azw3|ebook|audiobook|m4b|comics?)\b/;
const passwordWords = /\b(pass|password|passwords|passwd|pwd|unlock|key)\b/;
/** Invisible characters that can reverse how a name reads, hiding its real extension. */
const directionControls = /[\u202A-\u202E\u2066-\u2069\u200E\u200F\u061C]/;
/** Characters that take no space, which can pad a disguise invisibly. */
const invisible = /[\u00AD\u180E\u200B-\u200D\u2060\uFEFF]/g;
const doubleExtension = /\.([a-z0-9]{2,5})\s*\.([a-z0-9-]{2,12})$/i;
const elsewhere = /\b(?:download|watch|stream)[\s._-]*(?:here|now|full|online|movie|link)|click[\s._-]*here|full[\s._-]*movie|codec|player|free[\s._-]*download/i;

/** Below these, a film is far too small for the quality its name claims. */
const smallest: Record<number, number> = { 2160: 1_000_000_000, 1080: 300_000_000, 720: 150_000_000 };
/** A whole film is almost never smaller than this, even at low quality. */
const smallestFilm = 100_000_000;

type Kind = "video" | "music" | "book" | "pictures" | "other";

interface Finding {
  level: "failed" | "warning";
  summary: string;
  detail: string;
  /** The files it's about, marked in OrbTorrent with `because`. */
  files?: DownloadFile[];
  because?: string;
}

const words = (text: string) => text.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
const squashed = (text: string) => text.toLowerCase().replace(/[^a-z0-9]/g, "");
const nameOf = (path: string) => path.split("/").pop() ?? path;
/** A name as Windows reads it: without invisible characters, or the dots and spaces it drops from the end. */
const cleaned = (name: string) => name.replace(invisible, "").replace(/[\s.]+$/, "");
const extensionOf = (path: string) => {
  const name = cleaned(nameOf(path));
  const dot = name.lastIndexOf(".");
  return dot > 0 ? name.slice(dot + 1).trim().toLowerCase() : "";
};
const stemOf = (path: string) => {
  const name = cleaned(nameOf(path));
  const dot = name.lastIndexOf(".");
  return dot > 0 ? name.slice(0, dot) : name;
};
const isArchive = (path: string) => archives.has(extensionOf(path)) || /\.(r\d{2}|\d{3})$/i.test(path);
/** The Mac app or other bundle a file is inside, as the path to it. */
const bundleOf = (path: string) => {
  const folders = path.split("/").slice(0, -1);
  const index = folders.findIndex((folder) => macBundles.has(extensionOf(folder)));
  return index >= 0 ? folders.slice(0, index + 1).join("/") : undefined;
};
/** Part of a Blu-ray disc, whose menus are Java programs. */
const onBluRayDisc = (path: string) => path.split("/").some((folder) => folder.toUpperCase() === "BDMV");
/** RARBG put a 99-byte text file with this name in its releases, to stop other sites copying them. */
const isRarbgPlaceholder = (file: DownloadFile) => /^rarbg(\.com)?_do_not_mirror\.exe$/i.test(nameOf(file.path)) && file.size <= 1024;
/** An extra, such as a sample, judged by the folders and name inside the download's own folder. */
const isExtra = (path: string) => {
  const parts = path.split("/");
  return extras.test(words(parts.slice(parts.length > 1 ? 1 : 0).join(" ")));
};
const formatSize = (bytes: number) => (bytes >= 1_000_000_000 ? `${(bytes / 1_000_000_000).toFixed(1)} GB` : `${Math.max(1, Math.round(bytes / 1_000_000))} MB`);
const visible = (name: string) => name.replace(new RegExp(directionControls.source, "g"), "�");
const listed = (names: string[]) => (names.length === 1 ? names[0] : `${names[0]} and ${names.length - 1} more`);
const sum = (files: DownloadFile[]) => files.reduce((total, file) => total + file.size, 0);

/** The film's year: the last year in its name, since a title can have one too, as in "Blade Runner 2049 (2017)". */
function releaseYear(name: string): number | undefined {
  const latest = new Date().getFullYear() + 5;
  const years = [...words(name).matchAll(/\b(?:19|20)\d\d\b/g)].map((match) => Number(match[0])).filter((year) => year <= latest);
  return years.at(-1);
}

const isSoftwareName = (name: string) => softwareWords.test(words(name)) || version.test(name);
const isEpisodeName = (name: string) => episodeMarker.test(words(name)) || animeEpisode.test(name);
/** Named like a film or an episode, by markers software, music and books don't use. */
function isVideoName(name: string): boolean {
  const named = words(name);
  return resolution.test(named) || isEpisodeName(name)
    || (releaseYear(name) !== undefined && (sourceOrCodec.test(named) || filmWords.test(named)));
}

export function kindOf(download: Download): Kind {
  const name = download.name;
  if (isSoftwareName(name) && !isVideoName(name)) return "other";
  const total = sum(download.files);
  const share = (extensions: Set<string>) => (total > 0 ? sum(download.files.filter((file) => extensions.has(extensionOf(file.path)))) / total : 0);
  if (share(videos) >= 0.5) return "video";
  if (share(songs) >= 0.5) return "music";
  if (share(books) >= 0.5) return "book";
  if (share(pictures) >= 0.5) return "pictures";
  // Named like a film, without a film's worth of video.
  return isVideoName(name) && !isSoftwareName(name) && !otherMedia.test(words(name)) ? "video" : "other";
}

export function findings(download: Download): Finding[] {
  const files = download.files;
  const found: Finding[] = [];
  const kind = kindOf(download);
  const isCourse = courseWords.test(words(download.name));
  const scriptsAreCode = isCourse || files.some((file) => code.has(extensionOf(file.path)));
  const isProgram = (extension: string) => macPrograms.has(extension)
    || (windowsPrograms.has(extension) && !(scriptsAreCode && scripts.has(extension)));
  /** Files and folders already reported, with everything inside them. */
  const reported = new Set<string>();
  const isReported = (path: string) => [...reported].some((done) => path === done || path.startsWith(`${done}/`));
  /** A file, or a folder's files, such as a Mac app's. */
  const filesAt = (path: string) => files.filter((file) => file.path === path || file.path.startsWith(`${path}/`));

  // Any download: a name that hides what a file, or a Mac app, really is.
  for (const file of files) {
    const parts = file.path.split("/");
    for (const [depth, part] of parts.entries()) {
      const path = parts.slice(0, depth + 1).join("/");
      if (isReported(path)) break;
      if (directionControls.test(part)) {
        found.push({
          level: "failed",
          summary: `Hides a file's real type with an invisible character: ${visible(part)}`,
          detail: `\`${visible(path)}\` uses a character that makes its name read backwards, so its real extension doesn't show.`,
          files: filesAt(path),
          because: "Its name hides what it really is",
        });
        reported.add(path);
        break;
      }
      const isFolder = depth < parts.length - 1;
      const double = doubleExtension.exec(cleaned(part));
      const pretendsToBe = double && disguises[double[1].toLowerCase()];
      const real = double?.[2].toLowerCase() ?? "";
      if (pretendsToBe && (isFolder ? macBundles.has(real) : isProgram(real))) {
        found.push({
          level: "failed",
          summary: `Contains a program disguised as a ${pretendsToBe}: ${cleaned(part)}`,
          detail: `\`${cleaned(path)}\` ends in .${real}, so it's a program, not a ${pretendsToBe}.`,
          files: filesAt(path),
          because: `A program disguised as a ${pretendsToBe}`,
        });
        reported.add(path);
        break;
      }
    }
  }

  if (kind !== "video" && kind !== "music" && kind !== "book") return found;

  // Films, music and books don't need a program to play or read.
  const programs = files.filter((file) => !isReported(file.path) && bundleOf(file.path) === undefined && !onBluRayDisc(file.path)
    && !isRarbgPlaceholder(file) && isProgram(extensionOf(file.path)));
  const bundles = [...new Set(files.map((file) => bundleOf(file.path)).filter((bundle): bundle is string => bundle !== undefined && !isReported(bundle)))];
  const programNames = [...programs.map((file) => cleaned(nameOf(file.path))), ...bundles.map(nameOf)];
  if (programNames.length > 0) {
    const included = `It includes ${programNames.map((name) => `\`${name}\``).join(", ")}.`;
    const programFiles = [...programs, ...bundles.flatMap(filesAt)];
    found.push(isCourse
      ? {
          level: "warning",
          summary: `A course that includes a program: ${listed(programNames)}`,
          detail: `Courses sometimes include the software they teach, but get it from its maker rather than open this one. ${included}`,
          files: programFiles,
          because: "A program: get it from its maker instead",
        }
      : {
          level: "failed",
          summary: `${{ video: "A video", music: "A music", book: "A book" }[kind]} download that includes a program: ${listed(programNames)}`,
          detail: `${{ video: "A film or episode never needs a program to play.", music: "Music never needs a program to play.", book: "A book never needs a program to read." }[kind]} ${included}`,
          files: programFiles,
          because: `A program, which ${{ video: "a video", music: "music", book: "a book" }[kind]} never needs`,
        });
  }

  // Links that send you somewhere else to download or watch it.
  const lures = files.filter((file) => links.has(extensionOf(file.path)) && elsewhere.test(nameOf(file.path)));
  if (lures.length > 0) {
    found.push({
      level: "warning",
      summary: `Tells you to download or watch it elsewhere: ${nameOf(lures[0].path)}`,
      detail: `${lures.map((file) => `\`${nameOf(file.path)}\``).join(", ")} ${lures.length === 1 ? "is a link" : "are links"} to another site. Don't open ${lures.length === 1 ? "it" : "them"}.`,
      files: lures,
      because: "A link to download or watch it elsewhere",
    });
  }

  if (kind !== "video") return found;
  const name = download.name;
  const named = words(name);
  const year = releaseYear(name);
  const isFilm = !isEpisodeName(name) && !isCourse && !notAFilm.test(named)
    && (quality.test(named) || (year !== undefined && (filmWords.test(named) || bracketYear.test(name))));
  const videoFiles = files.filter((file) => videos.has(extensionOf(file.path)));
  const mainVideos = videoFiles.filter((file) => !isExtra(file.path));
  const mainVideoBytes = sum(mainVideos);
  const archiveFiles = files.filter((file) => isArchive(file.path));

  // The video locked in an archive, with the password sold or hidden elsewhere.
  // A scene release's own .nfo is named after it, so a film called Key Largo or
  // Passengers doesn't count.
  const release = squashed(name);
  const passwords = files.filter((file) => {
    const stem = squashed(stemOf(file.path));
    const isRelease = stem.length >= 8 && (release.startsWith(stem) || stem.startsWith(release));
    return ["txt", "url", "html", "htm", "webloc", "pdf", "nfo"].includes(extensionOf(file.path))
      && passwordWords.test(words(stemOf(file.path))) && !isRelease;
  });
  const locked = archiveFiles.length > 0 && passwords.length > 0 && sum(archiveFiles) > mainVideoBytes;
  if (locked) {
    found.push({
      level: "failed",
      summary: `The video is locked in an archive, with the password elsewhere: ${nameOf(passwords[0].path)}`,
      detail: `The video is inside ${listed(archiveFiles.map((file) => `\`${nameOf(file.path)}\``))}, next to \`${nameOf(passwords[0].path)}\`. Fakes lock the video and sell or hide the password.`,
      files: [...archiveFiles, passwords[0]],
      because: "A locked archive, with the password elsewhere",
    });
  }

  // Too small for the quality its name claims, or for a film at all.
  const claimed = /\b(2160p|4k|uhd)\b/.test(named) ? 2160 : /\b1080[pi]\b/.test(named) ? 1080 : /\b720p\b/.test(named) ? 720 : undefined;
  if (isFilm && mainVideos.length > 0) {
    if (claimed !== undefined && mainVideoBytes < smallest[claimed]) {
      found.push({
        level: "warning",
        summary: `Only ${formatSize(mainVideoBytes)} of video, too small for a ${claimed}p film`,
        detail: `A ${claimed}p film is usually well over ${formatSize(smallest[claimed])}. This one has ${formatSize(mainVideoBytes)} of video.`,
      });
    } else if (mainVideoBytes < smallestFilm) {
      found.push({
        level: "warning",
        summary: `Only ${formatSize(mainVideoBytes)} of video, too small for a whole film`,
        detail: `Even at low quality, a whole film is almost always over ${formatSize(smallestFilm)}. This one has ${formatSize(mainVideoBytes)} of video.`,
      });
    }
  }

  // A film from a year that hasn't come yet.
  const thisYear = new Date().getFullYear();
  if (isFilm && year !== undefined && year > thisYear) {
    found.push({
      level: "warning",
      summary: `Says it's a ${year} film, which can't be out yet`,
      detail: `Its name says it's from ${year}, and it's ${thisYear}, so no real copy of it can exist yet.`,
    });
  }

  // The classic "codec required" fake.
  if (videoFiles.length > 0 && videoFiles.every((file) => ["wmv", "asf"].includes(extensionOf(file.path)))) {
    found.push({
      level: "warning",
      summary: `Its only video is .${extensionOf(videoFiles[0].path)}, a common sign of a “codec required” fake`,
      detail: "Fakes often use .wmv or .asf video that asks you to download a codec or player, which is malware.",
      files: videoFiles,
      because: "Video that may ask you to download a codec",
    });
  }

  // Named like a film, without a film. Private trackers share scene releases
  // in their original archives, so those are expected there.
  if (isFilm && mainVideos.length === 0 && !locked) {
    if (archiveFiles.length === 0) {
      found.push({ level: "warning", summary: "Named like a film, but has no video file", detail: "None of its files is a video." });
    } else if (!download.isPrivate) {
      found.push({ level: "warning", summary: "Named like a film, but its video is inside an archive", detail: "Films are rarely shared in archives any more, and fakes often are." });
    }
  }
  return found;
}

export default async function check(download: Download): Promise<Result> {
  const found = findings(download);
  const failed = found.filter((finding) => finding.level === "failed");
  const warnings = found.filter((finding) => finding.level === "warning");
  if (found.length === 0) {
    const kind = kindOf(download);
    const isMedia = kind === "video" || kind === "music" || kind === "book";
    return { status: "passed", summary: isMedia ? "No signs of a fake" : "No disguised programs" };
  }
  const reasons = found.map((finding) => `- ${finding.detail}`).join("\n");
  const advice = failed.length > 0
    ? "OrbTorrent is holding it so nothing downloads. If you didn't expect this, remove it; otherwise choose Download Anyway."
    : "It's downloading. Take a look before you open its files.";
  // Each file it's about, marked beside the file, the worst first.
  const files: FileResult[] = [...failed, ...warnings].flatMap((finding) =>
    (finding.files ?? []).map((file) => ({ file, status: finding.level, summary: finding.because })));
  return {
    status: failed.length > 0 ? "failed" : "warning",
    summary: (failed[0] ?? warnings[0]).summary,
    details: `${reasons}\n\n${advice}`,
    ...(files.length > 0 && { files }),
  };
}
