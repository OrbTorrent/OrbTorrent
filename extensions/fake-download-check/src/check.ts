import { Download, DownloadFile, Result } from "@orbtorrent/api";

// Looks at the names and sizes of a download's files, before any of it
// downloads, for the signs fakes share. Everything here is local: it sends
// nothing anywhere.

const videos = new Set(["mkv", "mp4", "avi", "mov", "wmv", "asf", "m4v", "mpg", "mpeg", "webm", "flv", "ts", "m2ts", "vob", "3gp", "ogv", "rmvb", "divx"]);
const windowsPrograms = new Set(["exe", "scr", "com", "bat", "cmd", "msi", "lnk", "vbs", "vbe", "js", "jse", "ps1", "jar", "pif", "hta", "wsf", "cpl", "reg"]);
const macPrograms = new Set(["dmg", "pkg", "command"]);
const archives = new Set(["rar", "zip", "7z", "tar", "gz", "tgz", "bz2", "xz"]);
const links = new Set(["url", "webloc", "html", "htm"]);
/** What a program pretends to be, by the extension it hides behind. */
const disguises: Record<string, string> = {
  ...Object.fromEntries([...videos].map((extension) => [extension, "video"])),
  ...Object.fromEntries(["jpg", "jpeg", "png", "gif", "webp"].map((extension) => [extension, "picture"])),
  ...Object.fromEntries(["pdf", "txt", "nfo", "doc", "docx", "rtf"].map((extension) => [extension, "document"])),
  ...Object.fromEntries(["mp3", "flac", "m4a", "wav", "aac", "ogg"].map((extension) => [extension, "song"])),
  ...Object.fromEntries(["srt", "sub", "ass", "idx"].map((extension) => [extension, "subtitle"])),
};

const separator = String.raw`[\s._\-\[\]()]`;
const qualityMarker = new RegExp(String.raw`(?:^|${separator})(2160p|1080p|720p|480p|4k|uhd|hdr(?:10)?|web${separator}?dl|webrip|blu${separator}?ray|bdrip|brrip|dvdrip|hdtv|hdrip|x26[45]|h${separator}?26[45]|hevc|xvid|divx|remux|hdcam|camrip|telesync|hdts)(?=$|${separator})`, "i");
const episodeMarker = new RegExp(String.raw`(?:^|${separator})(s\d{1,2}${separator}?e\d{1,3}|s\d{1,2}(?=$|${separator})|season${separator}?\d+|\d{1,2}x\d{2}|episode${separator}?\d+|complete${separator}series)`, "i");
/** Invisible characters that can reverse how a name reads, hiding its real extension. */
const directionControls = /[‪-‮⁦-⁩‎‏]/;
const doubleExtension = /\.([a-z0-9]{2,5})\s*\.([a-z0-9]{2,7})$/i;
const passwordFile = /pass(?:word)?|pwd|unlock|(?:^|[\s._-])key(?:$|[\s._-])/i;
const elsewhere = /\b(?:download|watch|stream)[\s._-]*(?:here|now|full|online|movie|link)|click[\s._-]*here|full[\s._-]*movie|codec|player|free[\s._-]*download/i;

interface Finding {
  level: "failed" | "warning";
  summary: string;
  detail: string;
}

const nameOf = (path: string) => path.split("/").pop() ?? path;
const extensionOf = (path: string) => {
  const name = nameOf(path);
  const dot = name.lastIndexOf(".");
  return dot > 0 ? name.slice(dot + 1).trim().toLowerCase() : "";
};
const isArchive = (path: string) => archives.has(extensionOf(path)) || /\.(r\d{2}|\d{3})$/i.test(path);
/** A Mac app, which is a folder: "Player.app/Contents/MacOS/Player". */
const appBundle = (path: string) => path.split("/").slice(0, -1).find((component) => component.toLowerCase().endsWith(".app"));
const gigabytes = (bytes: number) => `${(bytes / 1_000_000_000).toFixed(1)} GB`;
const visible = (name: string) => name.replace(directionControls, "�");
const listed = (files: string[]) => (files.length === 1 ? files[0] : `${files[0]} and ${files.length - 1} more`);

export function findings(download: Download): Finding[] {
  const files = download.files;
  const found: Finding[] = [];
  const reported = new Set<number>();

  // Any download: a name that hides what the file really is.
  for (const file of files) {
    const name = nameOf(file.path);
    if (directionControls.test(name)) {
      found.push({
        level: "failed",
        summary: `Hides a file's real type with an invisible character: ${visible(name)}`,
        detail: `\`${visible(file.path)}\` uses a character that makes its name read backwards, so its real extension doesn't show.`,
      });
      reported.add(file.index);
      continue;
    }
    const double = doubleExtension.exec(name);
    const kind = double && disguises[double[1].toLowerCase()];
    if (double && kind && (windowsPrograms.has(double[2].toLowerCase()) || macPrograms.has(double[2].toLowerCase()))) {
      found.push({
        level: "failed",
        summary: `Contains a program disguised as a ${kind}: ${name}`,
        detail: `\`${file.path}\` ends in .${double[2].toLowerCase()}, so it's a program, not a ${kind}.`,
      });
      reported.add(file.index);
    }
  }

  const totalBytes = files.reduce((sum, file) => sum + file.size, 0);
  const videoFiles = files.filter((file) => videos.has(extensionOf(file.path)));
  const videoBytes = videoFiles.reduce((sum, file) => sum + file.size, 0);
  const archiveFiles = files.filter((file) => isArchive(file.path));
  const archiveBytes = archiveFiles.reduce((sum, file) => sum + file.size, 0);
  const isEpisode = episodeMarker.test(download.name);
  const claimsQuality = qualityMarker.test(download.name);
  const isVideo = claimsQuality || isEpisode || (totalBytes > 0 && videoBytes >= totalBytes / 2);
  if (!isVideo) return found;
  const isFilm = claimsQuality && !isEpisode;

  // A film or episode doesn't need a program to play.
  const programs = files.filter((file) => !reported.has(file.index)
    && (windowsPrograms.has(extensionOf(file.path)) || macPrograms.has(extensionOf(file.path))));
  const apps = [...new Set(files.map((file) => appBundle(file.path)).filter((app): app is string => app !== undefined))];
  const programNames = [...programs.map((file) => nameOf(file.path)), ...apps];
  if (programNames.length > 0) {
    found.push({
      level: "failed",
      summary: `A video download that includes a program: ${listed(programNames)}`,
      detail: `A film or episode never needs a program to play. It includes ${programNames.map((name) => `\`${name}\``).join(", ")}.`,
    });
  }

  // The video locked in an archive, with the password sold or hidden elsewhere.
  const passwords = files.filter((file) => passwordFile.test(nameOf(file.path))
    && ["txt", "url", "html", "htm", "webloc", "pdf", "nfo"].includes(extensionOf(file.path)));
  const locked = archiveFiles.length > 0 && passwords.length > 0 && archiveBytes > videoBytes;
  if (locked) {
    found.push({
      level: "failed",
      summary: `The video is locked in an archive, with the password elsewhere: ${nameOf(passwords[0].path)}`,
      detail: `The video is inside ${listed(archiveFiles.map((file) => `\`${nameOf(file.path)}\``))}, next to \`${nameOf(passwords[0].path)}\`. Fakes lock the video and sell or hide the password.`,
    });
  }

  // Too small for the quality its name claims.
  const claimed = /2160p|4k|uhd/i.test(download.name) ? 2160 : /1080p/i.test(download.name) ? 1080 : undefined;
  const smallest = claimed === 2160 ? 1_000_000_000 : claimed === 1080 ? 300_000_000 : undefined;
  if (isFilm && smallest !== undefined && videoFiles.length > 0 && videoBytes < smallest) {
    found.push({
      level: "warning",
      summary: `Only ${gigabytes(videoBytes)} of video, too small for a ${claimed}p film`,
      detail: `A ${claimed}p film is usually well over ${gigabytes(smallest)}. This one has ${gigabytes(videoBytes)} of video.`,
    });
  }

  // The classic "codec required" fake.
  if (videoFiles.length > 0 && videoFiles.every((file) => ["wmv", "asf"].includes(extensionOf(file.path)))) {
    found.push({
      level: "warning",
      summary: `Its only video is .${extensionOf(videoFiles[0].path)}, a common sign of a “codec required” fake`,
      detail: "Fakes often use .wmv or .asf video that asks you to download a codec or player, which is malware.",
    });
  }

  // Links that send you somewhere else to download or watch it.
  const lures = files.filter((file) => links.has(extensionOf(file.path)) && elsewhere.test(nameOf(file.path)));
  if (lures.length > 0) {
    found.push({
      level: "warning",
      summary: `Tells you to download or watch it elsewhere: ${nameOf(lures[0].path)}`,
      detail: `${lures.map((file) => `\`${nameOf(file.path)}\``).join(", ")} ${lures.length === 1 ? "is a link" : "are links"} to another site. Don't open ${lures.length === 1 ? "it" : "them"}.`,
    });
  }

  // Named like a film, without a film.
  if (isFilm && videoFiles.length === 0 && !locked) {
    found.push(archiveFiles.length > 0
      ? { level: "warning", summary: "Named like a film, but its video is inside an archive", detail: "Films are rarely shared in archives any more, and fakes often are." }
      : { level: "warning", summary: "Named like a film, but has no video file", detail: "None of its files is a video." });
  }
  return found;
}

export default async function check(download: Download): Promise<Result> {
  const found = findings(download);
  const failed = found.filter((finding) => finding.level === "failed");
  const warnings = found.filter((finding) => finding.level === "warning");
  if (found.length === 0) {
    const isVideo = download.files.some((file: DownloadFile) => videos.has(extensionOf(file.path)));
    return { status: "passed", summary: isVideo ? "No signs of a fake" : "No disguised programs" };
  }
  const reasons = found.map((finding) => `- ${finding.detail}`).join("\n");
  const advice = failed.length > 0
    ? "OrbTorrent is holding it so nothing downloads. If you didn't expect this, remove it; otherwise choose Download Anyway."
    : "It's downloading. Take a look before you open its files.";
  return {
    status: failed.length > 0 ? "failed" : "warning",
    summary: (failed[0] ?? warnings[0]).summary,
    details: `${reasons}\n\n${advice}`,
  };
}
