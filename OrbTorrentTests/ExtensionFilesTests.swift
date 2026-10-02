import Darwin
import Foundation
import Testing
@testable import OrbTorrent

/// A download's folder in the temporary folder, with a film in it.
private final class DownloadFolder {
    let root = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-added-\(UUID().uuidString)", directoryHint: .isDirectory)
    var film: URL { root.appending(path: "Film (2024)/Film.2024.1080p.mkv") }

    init() throws {
        try FileManager.default.createDirectory(at: film.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("film".utf8).write(to: film)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func adder(allowed: Bool = true, replaceable: Set<String> = []) -> ExtensionFileAdder {
        ExtensionFileAdder(folder: root, files: [0: film], allowed: allowed, replaceable: replaceable)
    }

    func text(_ path: String) -> String? {
        try? String(contentsOf: root.appending(path: path), encoding: .utf8)
    }
}

struct ExtensionFileAdderTests {
    @Test func addsAFileNextToTheDownloadsNamedAfterIt() async throws {
        let folder = try DownloadFolder()
        let adder = folder.adder()
        let saved = try await adder.save(file: 0, suffix: ".en.srt", contents: Data("1\nHello\n".utf8))
        #expect(saved == .init(path: "Film (2024)/Film.2024.1080p.en.srt", size: 8))
        #expect(folder.text(saved.path) == "1\nHello\n")
        #expect(await adder.added == ["Film (2024)/Film.2024.1080p.en.srt"])

        // Readable, never runnable, and marked as downloaded.
        let attributes = try FileManager.default.attributesOfItem(atPath: folder.root.appending(path: saved.path).path)
        #expect((attributes[.posixPermissions] as? Int).map { $0 & 0o111 } == 0)
        #expect(getxattr(folder.root.appending(path: saved.path).path, "com.apple.quarantine", nil, 0, 0, 0) > 0)
    }

    /// The engine can give a save folder as /private/tmp/…, which macOS
    /// shortens to /tmp/… only for paths that exist, as a new file doesn't yet.
    @Test func recordsTheFolderOfAFileInAPrivatePath() async throws {
        let folder = try DownloadFolder()
        let privateRoot = URL(fileURLWithPath: "/private" + folder.root.resolvingSymlinksInPath().path.replacingOccurrences(of: "/private", with: ""), isDirectory: true)
        let adder = ExtensionFileAdder(folder: privateRoot, files: [0: privateRoot.appending(path: "Film (2024)/Film.2024.1080p.mkv")], allowed: true)
        let saved = try await adder.save(file: 0, suffix: ".en.srt", contents: Data("x".utf8))
        #expect(saved.path == "Film (2024)/Film.2024.1080p.en.srt")
        #expect(FileActions.addedFiles([saved.path], in: privateRoot.path).count == 1)
    }

    @Test func needsItsPermissionAndAFinishedFile() async throws {
        let folder = try DownloadFolder()
        await #expect(throws: ExtensionRefusal(message: "Adding files isn't allowed. Add \"files\": \"add\" to permissions in package.json, or [\"contents\", \"add\"] to read files too.")) {
            try await folder.adder(allowed: false).save(file: 0, suffix: ".en.srt", contents: Data())
        }
        await #expect(throws: ExtensionRefusal(message: "File 3 isn't available: it isn't downloaded yet, or it isn't part of this download.")) {
            try await folder.adder().save(file: 3, suffix: ".en.srt", contents: Data())
        }
    }

    @Test func onlySubtitlesTextImagesAndChecksums() async throws {
        let folder = try DownloadFolder()
        for suffix in [".command", ".app", ".sh", ".pkg", ".html", ".webloc", ".terminal", ".scpt"] {
            await #expect(throws: ExtensionRefusal.self, "\(suffix)") {
                try await folder.adder().save(file: 0, suffix: suffix, contents: Data("x".utf8))
            }
        }
        for suffix in [".srt", ".en.forced.srt", "-poster.jpg", ".nfo", " (Director's Cut).sha256", "_cover.PNG"] {
            _ = try await folder.adder().save(file: 0, suffix: suffix, contents: Data("x".utf8))
        }
    }

    @Test func aSuffixCantLeadToAnotherFolder() async throws {
        let folder = try DownloadFolder()
        for suffix in ["/../../.zshrc.txt", "en.srt", ".en\\x.srt", ".srt:x", ".", "", ".srt\n.txt", String(repeating: "a", count: 70) + ".srt"] {
            #expect(!ExtensionFileAdder.isSuffix(suffix), "\(suffix)")
        }
        let escapes = try? await folder.adder().save(file: 0, suffix: "/../../escaped.txt", contents: Data("x".utf8))
        #expect(escapes == nil)
        #expect(!FileManager.default.fileExists(atPath: folder.root.deletingLastPathComponent().appending(path: "escaped.txt").path))
    }

    @Test func neverReplacesAFileItDidntAdd() async throws {
        let folder = try DownloadFolder()
        let mine = folder.root.appending(path: "Film (2024)/Film.2024.1080p.en.srt")
        try Data("the user's own".utf8).write(to: mine)
        await #expect(throws: ExtensionRefusal(message: "“Film.2024.1080p.en.srt” already exists. An extension can't replace a file it didn't add.")) {
            try await folder.adder().save(file: 0, suffix: ".en.srt", contents: Data("new".utf8))
        }
        #expect(folder.text("Film (2024)/Film.2024.1080p.en.srt") == "the user's own")

        // Nor a link put there, even one that leads nowhere.
        let target = folder.root.appending(path: "Film (2024)/Film.2024.1080p.nfo")
        try FileManager.default.createSymbolicLink(at: target, withDestinationURL: folder.root.appending(path: "elsewhere.txt"))
        await #expect(throws: ExtensionRefusal.self) {
            try await folder.adder(replaceable: ["Film (2024)/Film.2024.1080p.nfo"]).save(file: 0, suffix: ".nfo", contents: Data("x".utf8))
        }
        #expect(!FileManager.default.fileExists(atPath: folder.root.appending(path: "elsewhere.txt").path))
    }

    @Test func replacesAFileThisHookAddedBefore() async throws {
        let folder = try DownloadFolder()
        _ = try await folder.adder().save(file: 0, suffix: ".en.srt", contents: Data("first".utf8))
        let again = folder.adder(replaceable: ["Film (2024)/Film.2024.1080p.en.srt"])
        _ = try await again.save(file: 0, suffix: ".en.srt", contents: Data("better".utf8))
        #expect(folder.text("Film (2024)/Film.2024.1080p.en.srt") == "better")
        // Nothing left over from replacing it.
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.film.deletingLastPathComponent().path).sorted()
            == ["Film.2024.1080p.en.srt", "Film.2024.1080p.mkv"])
    }

    @Test func refusesAFileWhoseFolderLeadsOutOfTheDownloads() async throws {
        let folder = try DownloadFolder()
        let outside = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-outside-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: outside) }
        try Data("x".utf8).write(to: outside.appending(path: "Film.mkv"))
        try FileManager.default.createSymbolicLink(at: folder.root.appending(path: "Linked"), withDestinationURL: outside)
        let adder = ExtensionFileAdder(folder: folder.root, files: [0: folder.root.appending(path: "Linked/Film.mkv")], allowed: true)
        await #expect(throws: ExtensionRefusal.self) { try await adder.save(file: 0, suffix: ".en.srt", contents: Data("x".utf8)) }
        #expect(!FileManager.default.fileExists(atPath: outside.appending(path: "Film.en.srt").path))
    }

    @Test func limitsTheSizeOfEachFileAndOfARun() async throws {
        let folder = try DownloadFolder()
        await #expect(throws: ExtensionRefusal(message: "“Film.2024.1080p.txt” is larger than 10 MB, the most an extension can add in one file.")) {
            try await folder.adder().save(file: 0, suffix: ".txt", contents: Data(count: ExtensionFileAdder.maximumFile + 1))
        }
        let adder = folder.adder()
        for index in 0..<5 {
            _ = try await adder.save(file: 0, suffix: ".\(index).txt", contents: Data(count: ExtensionFileAdder.maximumFile))
        }
        await #expect(throws: ExtensionRefusal.self) { try await adder.save(file: 0, suffix: ".6.txt", contents: Data(count: 1)) }
    }
}

struct ExtensionResponseTests {
    @Test func textArrivesAsItIsAndBytesInBase64() {
        let text = ExtensionNetwork.Response(status: 200, headers: [:], body: Data("Café".utf8), url: "https://a.example")
        #expect(text.json["body"] == "Café")
        #expect(text.json["encoding"] == nil)
        let bytes = Data((0...255).map(UInt8.init))
        let binary = ExtensionNetwork.Response(status: 200, headers: [:], body: bytes, url: "https://a.example")
        #expect(binary.json["encoding"] == "base64")
        #expect(binary.json["body"]?.string.flatMap { Data(base64Encoded: $0) } == bytes)
    }
}

struct ExtensionRelayTests {
    /// Sends a request to the relay and reads its first line back.
    func ask(_ relay: ExtensionRelay, _ request: String) async throws -> String {
        let port = try #require(await relay.start())
        return try await Task.detached {
            let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
            defer { close(socket) }
            var address = sockaddr_in()
            address.sin_family = sa_family_t(AF_INET)
            address.sin_port = port.bigEndian
            address.sin_addr.s_addr = inet_addr("127.0.0.1")
            let connected = withUnsafePointer(to: &address) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
            guard connected == 0 else { throw POSIXError(.ECONNREFUSED) }
            _ = request.withCString { send(socket, $0, strlen($0), 0) }
            var buffer = [UInt8](repeating: 0, count: 256)
            let count = recv(socket, &buffer, buffer.count, 0)
            return String(decoding: buffer.prefix(max(count, 0)), as: UTF8.self).components(separatedBy: "\r\n").first ?? ""
        }.value
    }

    @Test func readsOnlyAConnectToAHostOnTheHTTPSPort() {
        #expect(ExtensionRelay.host(inConnectRequest: "CONNECT www.virustotal.com:443 HTTP/1.1\r\nHost: www.virustotal.com:443") == "www.virustotal.com")
        #expect(ExtensionRelay.host(inConnectRequest: "CONNECT WWW.Example.COM:443 HTTP/1.1") == "www.example.com")
        for request in ["GET / HTTP/1.1", "CONNECT example.com:22 HTTP/1.1", "CONNECT example.com HTTP/1.1",
                        "CONNECT [::1]:443 HTTP/1.1", "CONNECT localhost:443 HTTP/1.1", "CONNECT a b:443 HTTP/1.1"] {
            #expect(ExtensionRelay.host(inConnectRequest: request) == nil, "\(request)")
        }
    }

    /// The relay looks the host up itself when it connects, so a host that
    /// answered with an internet address for the check and a local one now
    /// gets nowhere.
    @Test func refusesAHostThatNowPointsToThisMacOrTheLocalNetwork() async throws {
        for addresses in [["127.0.0.1"], ["192.168.1.1"], ["93.184.216.34", "10.0.0.1"], []] {
            let relay = ExtensionRelay(resolve: { _ in addresses })
            let answer = try await ask(relay, "CONNECT rebinding.example:443 HTTP/1.1\r\nHost: rebinding.example:443\r\n\r\n")
            #expect(answer == "HTTP/1.1 403 Forbidden", "\(addresses)")
        }
    }

    @Test func refusesAnythingButAConnect() async throws {
        let relay = ExtensionRelay(resolve: { _ in ["93.184.216.34"] })
        #expect(try await ask(relay, "GET http://example.com/ HTTP/1.1\r\nHost: example.com\r\n\r\n") == "HTTP/1.1 400 Bad Request")
        #expect(try await ask(relay, "CONNECT example.com:80 HTTP/1.1\r\n\r\n") == "HTTP/1.1 400 Bad Request")
    }
}

/// Files an extension added go with their download when it's moved or removed.
@MainActor
struct AddedFilesTests {
    @Test func removingADownloadRemovesWhatItsExtensionsAddedAndEmptiedFolders() throws {
        let folder = try DownloadFolder()
        let subtitle = folder.root.appending(path: "Film (2024)/Film.2024.1080p.en.srt")
        try Data("x".utf8).write(to: subtitle)
        // The engine already deleted the film.
        try FileManager.default.removeItem(at: folder.film)
        let errors = FileActions.removeAdded(["Film (2024)/Film.2024.1080p.en.srt", "../outside.txt", "missing.srt"],
                                             in: folder.root.path, trash: false)
        #expect(errors.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: subtitle.path))
        #expect(!FileManager.default.fileExists(atPath: subtitle.deletingLastPathComponent().path))
        #expect(FileManager.default.fileExists(atPath: folder.root.path))
    }

    @Test func movingADownloadTakesWhatItsExtensionsAdded() throws {
        let folder = try DownloadFolder()
        try Data("x".utf8).write(to: folder.root.appending(path: "Film (2024)/Film.2024.1080p.en.srt"))
        let destination = folder.root.appending(path: "Moved", directoryHint: .isDirectory)
        FileActions.moveAdded(["Film (2024)/Film.2024.1080p.en.srt"], from: folder.root.path, to: destination)
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "Film (2024)/Film.2024.1080p.en.srt").path))
        #expect(!FileManager.default.fileExists(atPath: folder.root.appending(path: "Film (2024)/Film.2024.1080p.en.srt").path))
    }
}

/// A hook in OrbTorrent's own host adding a file and asking for a notification.
@MainActor
struct ExtensionAddsFilesTests {
    @Test func aHookAddsASubtitleAndTheResultSaysSo() async throws {
        let sandbox = try ExtensionSandbox()
        let folder = try DownloadFolder()
        let script = """
        var __orbExtension = { default: async (download) => {
          const saved = await __orb.call("files.save", { file: 0, suffix: ".en.srt", contents: { text: "1\\nHello\\n" } });
          return { status: "passed", summary: "Added " + saved.path, notify: true };
        }};
        """
        let target = try sandbox.makeExtension("subtitles", event: "afterFinish", script: script)
        // Built with API 1.1, adding files.
        let manifestURL = target.appending(path: "package.json")
        var manifest = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
        manifest["permissions"] = ["files": "add"]
        manifest["orbtorrent"] = ["api": "1.1.0"]
        try JSONSerialization.data(withJSONObject: manifest).write(to: manifestURL)

        let registry = sandbox.registry()
        let item = try registry.loadDevelopment(from: target)
        #expect(item.manifest.abilities.contains("Add files, such as subtitles, next to your downloads"))
        let extensions = Extensions(registry: registry, settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        final class Notices: @unchecked Sendable { var records: [CheckRecord] = [] }
        let notices = Notices()
        extensions.onNotice = { _, _, record in notices.records.append(record) }

        var download = ExtensionDownload(metadata: TorrentMetadata(infoHash: "4123456789abcdef0123456789abcdef01234567", name: "Film",
                                                                   files: [.init(id: 0, path: "Film (2024)/Film.2024.1080p.mkv", size: 4)]), skipped: [])
        download.onDisk = [0: folder.film]
        download.folder = folder.root
        let record = await extensions.run(item, item.manifest.hooks[0], on: download)
        #expect(record.status == .passed, "\(record.summary)")
        #expect(record.summary == "Added Film (2024)/Film.2024.1080p.en.srt")
        #expect(record.addedFiles == ["Film (2024)/Film.2024.1080p.en.srt"])
        #expect(folder.text("Film (2024)/Film.2024.1080p.en.srt") == "1\nHello\n")
        #expect(notices.records.map(\.summary) == [record.summary])

        // Run again, it may replace what it added, and it's still listed.
        let again = await extensions.run(item, item.manifest.hooks[0], on: download)
        #expect(again.status == .passed, "\(again.summary)")
        #expect(extensions.checks.records(for: download.id).first?.addedFiles == ["Film (2024)/Film.2024.1080p.en.srt"])
    }
}

@MainActor
struct FinishedProgramTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-program-\(UUID().uuidString)", directoryHint: .isDirectory)
    var log: URL { folder.appending(path: "program.log") }

    func script(_ body: String) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "finished.sh")
        try Data("#!/bin/sh\n\(body)\n".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    @Test func runsWithTheDownloadsDetailsAndNoShell() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let out = folder.appending(path: "out.txt")
        let program = try script("printf '%s|%s|%s|%s|%s' \"$1\" \"$ORB_NAME\" \"$ORB_HASH\" \"$ORB_FOLDER\" \"$ORB_PRIVATE\" > '\(out.path)'")
        // A name that would run a command if it went through a shell.
        let name = "Film\"; touch \(folder.path)/pwned; echo \""
        let torrent = Fixtures.torrent(hash: "f00d", name: name, savePath: folder.path, contentPath: folder.path + "/" + name, progress: 1)
        let status = await FinishedProgram.launch(try #require(FinishedProgram.executable(for: program)),
                                                  with: FinishedProgram.environment(for: torrent),
                                                  argument: torrent.contentPath, in: torrent.savePath, log: log)
        #expect(status == "Finished with exit code 0.")
        #expect(try String(contentsOf: out, encoding: .utf8) == "\(folder.path)/\(name)|\(name)|f00d|\(folder.path)|false")
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "pwned").path))
    }

    @Test func saysHowItEnded() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let program = try script("echo 'something went wrong' >&2; exit 3")
        let torrent = Fixtures.torrent(savePath: folder.path, contentPath: folder.path, progress: 1)
        let status = await FinishedProgram.launch(program, with: FinishedProgram.environment(for: torrent), argument: "", in: folder.path, log: log)
        #expect(status == "Finished with exit code 3.")
        #expect(try String(contentsOf: log, encoding: .utf8) == "something went wrong\n")
    }

    func torrent(_ hash: String, progress: Double) -> Torrent {
        Fixtures.torrent(hash: hash, name: "Film \(hash)", savePath: folder.path, contentPath: folder.path + "/Film", progress: progress)
    }

    /// Waits for something that happens in the background.
    func eventually(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() { try? await Task.sleep(for: .milliseconds(50)) }
    }

    @Test func runsForADownloadThatFinishesWhileOpen() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let ran = folder.appending(path: "ran.txt")
        let program = try script("echo \"$ORB_NAME\" >> '\(ran.path)'")
        let suite = TestDefaults.makeSuiteName()
        defer { TestDefaults.remove(suite) }
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.finishedProgram = program.path
        let sandbox = try ExtensionSandbox()
        let extensions = Extensions(registry: sandbox.registry(), settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        let finished = FinishedProgram(settings: settings, extensions: extensions, log: log)

        // At launch, what's finished already is left alone.
        finished.observe([torrent("a", progress: 1), torrent("b", progress: 0.5)])
        finished.observe([torrent("a", progress: 1), torrent("b", progress: 1)])
        await eventually { FileManager.default.fileExists(atPath: ran.path) }
        try await Task.sleep(for: .milliseconds(300))
        #expect(try String(contentsOf: ran, encoding: .utf8) == "Film b\n")
        let lines = try String(contentsOf: log, encoding: .utf8)
        #expect(lines.contains("Running \(program.path) for “Film b”"))
        #expect(lines.contains("Finished with exit code 0."))
    }

    @Test func doesntRunWhenACheckAfterFinishingFailed() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let ran = folder.appending(path: "ran.txt")
        let program = try script("echo ran >> '\(ran.path)'")
        let suite = TestDefaults.makeSuiteName()
        defer { TestDefaults.remove(suite) }
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.finishedProgram = program.path
        let sandbox = try ExtensionSandbox()
        let registry = sandbox.registry()
        try registry.loadDevelopment(from: try sandbox.makeExtension("scanner", event: "afterFinish",
            script: "var __orbExtension = { default: async () => ({ status: \"failed\", summary: \"Malware in setup.exe\" }) };"))
        let extensions = Extensions(registry: registry, settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        extensions.files = { _ in [Fixtures.file(0, "Film/setup.exe", progress: 1)] }
        let finished = FinishedProgram(settings: settings, extensions: extensions, log: log)

        for torrents in [[torrent("c", progress: 0.5)], [torrent("c", progress: 1)]] {
            extensions.observe(torrents)
            finished.observe(torrents)
        }
        await eventually { (try? String(contentsOf: log, encoding: .utf8))?.contains("Didn't run") == true }
        #expect(try String(contentsOf: log, encoding: .utf8).contains("Didn't run for “Film c”: Scanner found a problem. Malware in setup.exe"))
        #expect(!FileManager.default.fileExists(atPath: ran.path))
    }

    @Test func onlyAFileThatCanRun() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let program = try script("true")
        #expect(FinishedProgram.executable(for: program) == program)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: program.path)
        #expect(FinishedProgram.executable(for: program) == nil)
        #expect(FinishedProgram.executable(for: folder) == nil)
        #expect(FinishedProgram.executable(for: URL(fileURLWithPath: "/System/Applications/Calculator.app"))?.lastPathComponent == "Calculator")
    }

    @Test func theEnginesOwnWayOfRunningProgramsStaysOff() {
        let before = "[AutoRun]\nenabled=true\nprogram=/tmp/evil.sh \"%F\"\nOnTorrentAdded\\Enabled=true\nOnTorrentAdded\\Program=/tmp/evil.sh\n"
        let after = EngineConfiguration.configured(before, for: EngineCredentials(port: 1234, username: "orbtorrent", password: "secret"))
        #expect(after.contains("[AutoRun]\nenabled=false\nprogram=\nOnTorrentAdded\\Enabled=false\nOnTorrentAdded\\Program=\n"))
        #expect(!after.contains("evil"))
    }
}
