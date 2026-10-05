import Foundation
import Testing
@testable import OrbTorrent

/// The repository, for the official extensions and the SDK's shared fixtures.
private let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

/// A throwaway place for extensions, settings and results.
@MainActor
final class ExtensionSandbox {
    let root = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-extensions-\(UUID().uuidString)", directoryHint: .isDirectory)
    let suite = TestDefaults.makeSuiteName()
    var official: URL { root.appending(path: "Official", directoryHint: .isDirectory) }
    var installed: URL { root.appending(path: "Installed", directoryHint: .isDirectory) }

    init(officialExtensions: [String] = []) throws {
        try FileManager.default.createDirectory(at: official, withIntermediateDirectories: true)
        for name in officialExtensions {
            try FileManager.default.copyItem(at: repository.appending(path: "extensions/\(name)/dist"), to: official.appending(path: name))
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
        TestDefaults.remove(suite)
    }

    func registry() -> ExtensionRegistry {
        ExtensionRegistry(defaults: UserDefaults(suiteName: suite)!, officialFolder: official, installedFolder: installed)
    }

    func settings() -> ExtensionSettings {
        ExtensionSettings(file: root.appending(path: "settings.json"), secrets: MemorySecrets())
    }

    /// A built extension in a folder of its own.
    func makeExtension(_ name: String, in folder: URL? = nil, network: [String] = [], event: String = "beforeStart",
                       readsFiles: Bool = false,
                       script: String = "var __orbExtension = { default: () => ({ status: \"passed\", summary: \"Fine\" }) };") throws -> URL {
        let target = (folder ?? root.appending(path: "Sources")).appending(path: name, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: target.appending(path: "hooks"), withIntermediateDirectories: true)
        var permissions: [String: Any] = ["network": network]
        if readsFiles { permissions["files"] = "contents" }
        let hooks: [[String: String]] = [["name": "check", "title": "Check", "event": event]]
        let manifest: [String: Any] = [
            "name": name, "title": name.capitalized, "description": "A test extension.", "author": "tester",
            "hooks": hooks, "permissions": permissions, "orbtorrent": ["api": "1.0.0"],
        ]
        try JSONSerialization.data(withJSONObject: manifest).write(to: target.appending(path: "package.json"))
        try Data(script.utf8).write(to: target.appending(path: "hooks/check.js"))
        return target
    }
}

@MainActor
struct ExtensionRegistryTests {
    @Test func officialExtensionsLoadAndOnlyTheFakeCheckIsOnByDefault() throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check", "virustotal"])
        let registry = sandbox.registry()
        #expect(registry.extensions.map(\.name) == ["fake-download-check", "virustotal"])
        #expect(registry.isEnabled(registry.named("fake-download-check")!))
        #expect(!registry.isEnabled(registry.named("virustotal")!))
        #expect(registry.hooks(for: .beforeStart).map(\.1.name) == ["check"])
        #expect(registry.hooks(for: .afterFinish).isEmpty)
    }

    @Test func aDevelopmentCopyStandsInForTheOfficialOne() throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let registry = sandbox.registry()
        let copy = try sandbox.makeExtension("fake-download-check")
        let loaded = try registry.loadDevelopment(from: copy)
        #expect(loaded.source == .development)
        #expect(loaded.replacesOfficial)
        #expect(registry.extensions.count == 1)

        registry.remove(loaded)
        #expect(registry.named("fake-download-check")?.source == .official)
    }

    @Test func installsAnOrbextFileAndRefusesOfficialNames() throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let registry = sandbox.registry()
        let source = try sandbox.makeExtension("plex-mover", network: ["plex.example.com"])
        let archive = sandbox.root.appending(path: "plex-mover.orbext")
        let zip = Process()
        zip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        zip.arguments = ["-c", "-k", source.path, archive.path]
        try zip.run()
        zip.waitUntilExit()

        let candidate = try registry.inspect(archive)
        #expect(candidate.extension.manifest.abilities.contains("Connect to plex.example.com"))
        try registry.install(candidate)
        #expect(registry.named("plex-mover")?.source == .installed)
        #expect(registry.isEnabled(registry.named("plex-mover")!))

        let impostor = try sandbox.makeExtension("fake-download-check", in: sandbox.root.appending(path: "Impostor"))
        #expect(throws: ExtensionManifest.Invalid.self) { try registry.inspect(impostor) }
    }

    @Test func installingTakesOverFromADevelopmentCopy() throws {
        let sandbox = try ExtensionSandbox()
        let registry = sandbox.registry()
        let source = try sandbox.makeExtension("size-guard")
        try registry.loadDevelopment(from: source)
        #expect(registry.installed(named: "size-guard") == nil)

        try registry.install(registry.inspect(source))
        #expect(registry.named("size-guard")?.source == .installed)
        #expect(registry.installed(named: "size-guard") != nil)
        #expect(!registry.isKnownDevelopmentFolder(source))
        // Reopened, it's still the installed copy.
        #expect(sandbox.registry().named("size-guard")?.source == .installed)
    }

    @Test func anUpdateShowsWhatItCanNowDo() throws {
        let sandbox = try ExtensionSandbox()
        let registry = sandbox.registry()
        try registry.install(registry.inspect(try sandbox.makeExtension("notifier", network: ["ntfy.sh"])))
        let update = try registry.inspect(try sandbox.makeExtension("notifier", in: sandbox.root.appending(path: "Update"),
                                                                    network: ["ntfy.sh", "api.example.com"]))
        #expect(update.existing != nil)
        #expect(update.newAbilities == ["Connect to api.example.com"])
        registry.cancel(update)
    }

    @Test func refusesAnExtensionWithALink() throws {
        let sandbox = try ExtensionSandbox()
        let source = try sandbox.makeExtension("sneaky")
        try FileManager.default.createSymbolicLink(at: source.appending(path: "passwords"), withDestinationURL: URL(fileURLWithPath: "/etc/passwd"))
        #expect(throws: ExtensionManifest.Invalid.self) { try sandbox.registry().inspect(source) }
    }

    @Test func aFolderWithoutItsBuildIsListedAsAProblem() throws {
        let sandbox = try ExtensionSandbox()
        try FileManager.default.createDirectory(at: sandbox.installed.appending(path: "broken"), withIntermediateDirectories: true)
        let registry = sandbox.registry()
        #expect(registry.extensions.isEmpty)
        #expect(registry.problems.first?.message.contains("package.json") == true)
    }
}

@MainActor
struct ExtensionSettingsTests {
    @Test func settingsHaveValuesAndPasswordsGoToTheSecretStore() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["virustotal"])
        let item = sandbox.registry().named("virustotal")!
        let settings = sandbox.settings()
        let scope = item.manifest.preferences.first { $0.name == "scope" }!
        let apiKey = item.manifest.preferences.first { $0.name == "apiKey" }!

        #expect(settings.value(of: scope, in: item.name) == "risky")
        #expect(settings.missing(for: item).map(\.name) == ["apiKey"])

        try settings.setPassword("  sk-test-key ", for: apiKey, in: item.name)
        #expect(settings.missing(for: item).isEmpty)
        let resolved = await settings.resolved(for: item)
        #expect(resolved.values["apiKey"] == "sk-test-key")
        #expect(resolved.values["uploadUnknown"] == false)
        #expect(resolved.secrets == ["sk-test-key"])

        // Saved without the password itself.
        let saved = try String(contentsOf: sandbox.root.appending(path: "settings.json"), encoding: .utf8)
        #expect(!saved.contains("sk-test-key"))

        settings.remove(item.name)
        #expect(!settings.hasPassword(apiKey, in: item.name))
    }
}

@MainActor
struct ChecksStoreTests {
    @Test func remembersResultsAndHeldDownloads() throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let item = sandbox.registry().named("fake-download-check")!
        let file = sandbox.root.appending(path: "checks.json")
        let checks = ChecksStore(file: file)
        checks.update(CheckRecord(extension: item, hook: item.manifest.hooks[0], status: .failed, summary: "Contains a program"), for: "abc")
        checks.setGate(.held, for: "abc")
        #expect(checks.badge(for: "abc") == .held)
        checks.saveNow()

        let reloaded = ChecksStore(file: file)
        #expect(reloaded.records(for: "abc").first?.summary == "Contains a program")
        #expect(reloaded.gated == ["abc": .held])
        reloaded.setGate(nil, for: "abc")
        #expect(reloaded.badge(for: "abc") == .failed)
        reloaded.forget(["abc"])
        #expect(reloaded.entries.isEmpty)
    }

    /// Finishing more files of a download doesn't repeat what the user was told.
    @Test func saysWhatsFlaggedOnlyOnce() throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["virustotal"])
        let item = sandbox.registry().named("virustotal")!
        func record(_ status: CheckRecord.Status, _ files: [(Int, CheckRecord.Status)] = []) -> CheckRecord {
            var record = CheckRecord(extension: item, hook: item.manifest.hooks[0], status: status, summary: "")
            record.files = files.map { CheckRecord.FileResult(index: $0.0, path: "Pack/\($0.0).exe", status: $0.1) }
            return record
        }
        #expect(record(.failed, [(0, .failed)]).flagsMore(than: nil))
        #expect(record(.warning).flagsMore(than: record(.passed)))
        #expect(!record(.passed).flagsMore(than: nil))
        // The same file again, or one that's better now: nothing new.
        #expect(!record(.failed, [(0, .failed)]).flagsMore(than: record(.failed, [(0, .failed)])))
        #expect(!record(.failed, [(0, .failed), (1, .passed)]).flagsMore(than: record(.failed, [(0, .failed)])))
        #expect(!record(.warning).flagsMore(than: record(.warning)))
        // Another file, a file that got worse, or a worse result: news.
        #expect(record(.failed, [(0, .failed), (1, .warning)]).flagsMore(than: record(.failed, [(0, .failed)])))
        #expect(record(.failed, [(0, .failed)]).flagsMore(than: record(.warning, [(0, .warning)])))
        #expect(record(.failed).flagsMore(than: record(.warning)))
    }
}

@MainActor
struct CheckSummaryTests {
    @Test func saysWhatChecksFoundWorstFirst() throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check", "virustotal"])
        let registry = sandbox.registry()
        let fake = registry.named("fake-download-check")!
        let scan = registry.named("virustotal")!
        func record(_ item: InstalledExtension, _ status: CheckRecord.Status) -> CheckRecord {
            CheckRecord(extension: item, hook: item.manifest.hooks[0], status: status, summary: "")
        }

        let passed = CheckSummary(records: [record(fake, .passed), record(scan, .passed)], gate: nil)
        #expect(passed.title == "All 2 passed")
        #expect(passed.mark == .check)
        #expect(passed.byline == "Checked by Fake Download Check and VirusTotal Scan")

        let mixed = CheckSummary(records: [record(fake, .passed), record(scan, .failed)], gate: nil)
        #expect(mixed.title == "1 found a problem · 1 passed")
        #expect(mixed.records.first?.extensionName == "virustotal")
        #expect(mixed.segments == [.red, .checkPassed])
        #expect(mixed.mark == .cross)

        let running = CheckSummary(records: [record(fake, .passed), record(scan, .running)], gate: nil)
        #expect(running.isChecking)
        #expect(running.title == "Checking… 1 of 2 done")
        #expect(running.mark == nil)

        let failedWhileRunning = CheckSummary(records: [record(fake, .failed), record(scan, .running)], gate: nil)
        #expect(failedWhileRunning.mark == .cross)

        let waiting = CheckSummary(records: [], gate: .waiting)
        #expect(!waiting.isEmpty && waiting.title == "Checking…")

        let later = CheckSummary(records: [record(fake, .passed)], gate: nil,
                                 upcoming: [.init(item: scan, hook: scan.manifest.hooks[0], runsLater: true)])
        #expect(later.title == "1 passed · 1 more once it finishes")
        #expect(later.segments.count == 2)
        // Not a check yet: VirusTotal hasn't run.
        #expect(later.mark == .clock)

        let held = CheckSummary(records: [record(fake, .failed)], gate: .held)
        #expect(held.isHeld && held.title == "Held before it started")
    }
}

@MainActor
struct ExtensionsCoordinatorTests {
    func coordinator(_ sandbox: ExtensionSandbox) -> Extensions {
        Extensions(registry: sandbox.registry(), settings: sandbox.settings(),
                   checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
    }

    @Test func theFakeDownloadCheckHoldsADisguisedProgram() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let extensions = coordinator(sandbox)
        let metadata = TorrentMetadata(infoHash: "0123456789abcdef0123456789abcdef01234567", name: "Film.2024.1080p.WEB-DL",
                                       files: [.init(id: 0, path: "Film.2024.1080p.WEB-DL/Film.2024.1080p.mp4.exe", size: 2_400_000)])
        let records = await extensions.runBeforeStart(on: ExtensionDownload(metadata: metadata, skipped: []))
        #expect(records.map(\.status) == [.failed])
        #expect(records.first?.summary.contains("disguised as a video") == true)
        #expect(extensions.checks.records(for: metadata.infoHash) == records)
    }

    @Test func aRealReleasePasses() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let metadata = TorrentMetadata(infoHash: "1123456789abcdef0123456789abcdef01234567", name: "Film.2024.1080p.WEB-DL",
                                       files: [.init(id: 0, path: "Film.2024.1080p.WEB-DL/Film.mkv", size: 2_400_000_000)])
        let records = await coordinator(sandbox).runBeforeStart(on: ExtensionDownload(metadata: metadata, skipped: []))
        #expect(records.map(\.status) == [.passed])
    }

    /// Each of the Fake Download Check's own tests comes out the same in
    /// OrbTorrent's host, JavaScriptCore, as in `orb test`, which uses Node.js.
    @Test(arguments: try! FileManager.default.contentsOfDirectory(atPath: repository.appending(path: "extensions/fake-download-check/tests").path)
        .filter { $0.hasSuffix(".json") }.sorted())
    func theFakeDownloadCheckAgreesWithItsTests(test: String) async throws {
        let json = try JSONValue(data: Data(contentsOf: repository.appending(path: "extensions/fake-download-check/tests/\(test)")))
        let download = try #require(json["download"])
        let files = (download["files"]?.array ?? []).enumerated().map { index, file in
            TorrentMetadata.File(id: index, path: file["path"]?.string ?? "", size: Int64(file["size"]?.double ?? 0))
        }
        let metadata = TorrentMetadata(infoHash: String(repeating: "a", count: 40), name: download["name"]?.string ?? "",
                                       files: files, isPrivate: download["isPrivate"]?.bool ?? false)
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let records = await coordinator(sandbox).runBeforeStart(on: ExtensionDownload(metadata: metadata, skipped: []))
        let record = try #require(records.first)
        #expect(record.status.rawValue == json["expect"]?["status"]?.string, "\(record.summary)")
        if let text = json["expect"]?["summaryIncludes"]?.string {
            #expect(record.summary.localizedCaseInsensitiveContains(text), "\(record.summary)")
        }
    }

    @Test func anExtensionThatNeedsSetupIsSkipped() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["virustotal"])
        let extensions = coordinator(sandbox)
        let item = extensions.registry.named("virustotal")!
        let metadata = TorrentMetadata(infoHash: "2123456789abcdef0123456789abcdef01234567", name: "Tool",
                                       files: [.init(id: 0, path: "Tool/setup.exe", size: 1_000)])
        let record = await extensions.run(item, item.manifest.hooks[0], on: ExtensionDownload(metadata: metadata, skipped: []))
        #expect(record.status == .skipped)
        #expect(record.summary == "Needs setup: API key")
    }

    @Test func aHookReadsAFinishedDownloadsFilesThroughOrbTorrent() async throws {
        let sandbox = try ExtensionSandbox()
        let script = """
        var __orbExtension = { default: async (download) => {
          const hash = await __orb.call("files.sha256", { file: download.files[0].index });
          let refused;
          try { await __orb.call("files.sha256", { file: 7 }); } catch (error) { refused = error.message; }
          return { status: "passed", summary: hash, details: refused };
        }};
        """
        let registry = sandbox.registry()
        let item = try registry.loadDevelopment(from: try sandbox.makeExtension("hasher", event: "afterFinish", readsFiles: true, script: script))
        let extensions = Extensions(registry: registry, settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        let file = sandbox.root.appending(path: "hello.txt")
        try Data("hello".utf8).write(to: file)
        var download = ExtensionDownload(metadata: TorrentMetadata(infoHash: "3123456789abcdef0123456789abcdef01234567", name: "Hello",
                                                                   files: [.init(id: 0, path: "hello.txt", size: 5)]), skipped: [])
        download.onDisk = [0: file]
        let record = await extensions.run(item, item.manifest.hooks[0], on: download)
        #expect(record.summary == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        #expect(record.details?.contains("isn't available") == true)
    }

    @Test func aResultsFilesAreKeptProblemsFirstAndItIsNoBetterThanTheWorst() async throws {
        let sandbox = try ExtensionSandbox()
        let script = """
        var __orbExtension = { default: (download) => ({ status: "passed", summary: "Fine", files: [
          { file: 0, status: "passed" }, { file: download.files[1], status: "warning", summary: "Odd" },
          { file: 1, status: "failed", summary: "Bad\\nnews" }] }) };
        """
        let registry = sandbox.registry()
        let item = try registry.loadDevelopment(from: try sandbox.makeExtension("marker", script: script))
        let extensions = Extensions(registry: registry, settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        let metadata = TorrentMetadata(infoHash: "4123456789abcdef0123456789abcdef01234567", name: "Pack",
                                       files: [.init(id: 0, path: "Pack/film.mkv", size: 1), .init(id: 1, path: "Pack/setup.exe", size: 1)])
        let record = await extensions.run(item, item.manifest.hooks[0], on: ExtensionDownload(metadata: metadata, skipped: []))
        #expect(record.status == .failed)
        #expect(record.summary == "Fine")
        #expect(record.files?.map(\.path) == ["Pack/setup.exe", "Pack/film.mkv"])
        #expect(record.files?.first?.summary == "Bad news")
        #expect(extensions.fileProblems(of: metadata.infoHash)[1]?.map(\.line) == ["Marker: Bad news"])
        #expect(extensions.fileProblems(of: metadata.infoHash)[0] == nil)
        #expect(extensions.logs.entries["marker"]?.last?.message == "Its result said “passed”, but setup.exe is “failed”, so it shows as failed.")
    }

    @Test func aResultNamingAFileThatIsntThereDoesntFinish() async throws {
        let sandbox = try ExtensionSandbox()
        let script = "var __orbExtension = { default: () => ({ status: \"failed\", summary: \"Bad\", files: [{ file: 9, status: \"failed\" }] }) };"
        let registry = sandbox.registry()
        let item = try registry.loadDevelopment(from: try sandbox.makeExtension("marker", script: script))
        let extensions = Extensions(registry: registry, settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        let metadata = TorrentMetadata(infoHash: "5123456789abcdef0123456789abcdef01234567", name: "Pack",
                                       files: [.init(id: 0, path: "Pack/film.mkv", size: 1)])
        let record = await extensions.run(item, item.manifest.hooks[0], on: ExtensionDownload(metadata: metadata, skipped: []))
        #expect(record.status == .didNotFinish)
        #expect(record.summary == "Its result's “files” names a file that isn't part of this download. Pass a file from download.files, or its index.")
        #expect(record.files == nil)
    }

    @Test func verifyRunsTheExtensionsOwnCheck() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["virustotal"])
        let extensions = coordinator(sandbox)
        let item = extensions.registry.named("virustotal")!
        // An empty key is refused before anything is sent.
        let result = await extensions.verify(item)
        #expect(result.ok == false)
        #expect(result.message == "Enter your API key.")
    }
}

/// The SDK checks the same manifests (sdk/test/fixtures/manifests), so
/// `orb build` refuses what OrbTorrent would.
struct ExtensionManifestParityTests {
    @Test(arguments: try! FileManager.default.contentsOfDirectory(atPath: repository.appending(path: "sdk/test/fixtures/manifests").path)
        .filter { $0.hasSuffix(".json") }.sorted())
    func agreesWithTheSDK(fixture: String) throws {
        let data = try Data(contentsOf: repository.appending(path: "sdk/test/fixtures/manifests/\(fixture)"))
        let json = try JSONValue(data: data)
        let expected = Set((json["problems"]?.array ?? []).compactMap(\.string))
        do {
            _ = try ExtensionManifest(data: json["manifest"]!.data())
            #expect(expected.isEmpty, "OrbTorrent accepted what the SDK refuses")
        } catch let invalid as ExtensionManifest.Invalid {
            #expect(Set(invalid.problems) == expected)
        }
    }
}

/// When hooks run as the library changes: the gate before a download starts,
/// and hooks after it finishes.
@MainActor
struct ExtensionsTimingTests {
    final class Started: @unchecked Sendable {
        var hashes: [String] = []
    }

    func torrent(_ hash: String, name: String = "Film.2024.1080p.WEB-DL", state: String = "stoppedDL", progress: Double = 0,
                 hasMetadata: Bool = true, completedOn: Date? = nil, downloaded: Int = 0) -> Torrent {
        var json: [String: Any] = ["hash": hash, "name": name, "state": state, "progress": progress,
                                   "has_metadata": hasMetadata, "downloaded": downloaded, "save_path": "/tmp"]
        if let completedOn { json["completion_on"] = Int(completedOn.timeIntervalSince1970) }
        return try! JSONDecoder().decode(Torrent.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func coordinator(_ sandbox: ExtensionSandbox, files: [String], started: Started) -> Extensions {
        let extensions = Extensions(registry: sandbox.registry(), settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        extensions.files = { _ in files.enumerated().map { TorrentFile(index: $0.offset, name: $0.element, size: 2_000_000_000,
                                                                     progress: 0, priority: .normal, availability: 0) } }
        extensions.start = { started.hashes += $0 }
        return extensions
    }

    /// Waits for something the coordinator does in the background.
    func eventually(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() { try? await Task.sleep(for: .milliseconds(50)) }
    }

    @Test func aDownloadWaitsForItsFilesThenIsHeldWhenACheckFails() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let started = Started()
        let extensions = coordinator(sandbox, files: ["Film/Film.2024.1080p.mp4.exe"], started: started)
        extensions.gate("a1")
        extensions.observe([torrent("a1", state: "metaDL", hasMetadata: false)])
        try await Task.sleep(for: .milliseconds(200))
        #expect(extensions.checks.records(for: "a1").isEmpty)

        extensions.observe([torrent("a1")])
        await eventually { extensions.checks.gate(for: "a1") == .held }
        #expect(extensions.checks.gate(for: "a1") == .held)
        #expect(started.hashes.isEmpty)

        // Starting it by hand is the user's choice.
        extensions.observe([torrent("a1", state: "stalledDL")])
        #expect(extensions.checks.gate(for: "a1") == nil)
    }

    @Test func aDownloadThatPassesIsStarted() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let started = Started()
        let extensions = coordinator(sandbox, files: ["Film/Film.2024.1080p.mkv"], started: started)
        extensions.gate("b1")
        extensions.observe([torrent("b1")])
        await eventually { !started.hashes.isEmpty }
        #expect(started.hashes == ["b1"])
        #expect(extensions.checks.gate(for: "b1") == nil)
        #expect(extensions.checks.records(for: "b1").map(\.status) == [.passed])
    }

    @Test func aDownloadAddedStoppedIsCheckedAndStaysStopped() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let started = Started()
        let extensions = coordinator(sandbox, files: ["Film/Film.2024.1080p.mkv"], started: started)
        extensions.gate("d1", startsAfterChecks: false)
        extensions.observe([torrent("d1")])
        await eventually { extensions.checks.gate(for: "d1") == nil }
        #expect(extensions.checks.records(for: "d1").map(\.status) == [.passed])
        #expect(started.hashes.isEmpty)
    }

    @Test func turningExtensionsOffLetsGoOfDownloadsAndHidesChecks() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let started = Started()
        let extensions = coordinator(sandbox, files: ["Film/Film.2024.1080p.mkv"], started: started)
        extensions.gate("waits")
        extensions.gate("stays", startsAfterChecks: false)
        extensions.checks.setGate(.held, for: "held")
        #expect(!extensions.summary(of: torrent("held")).isEmpty)

        extensions.setOn(false)
        // Meant to start once its checks passed: it starts. The rest stay paused.
        await eventually { !started.hashes.isEmpty }
        #expect(started.hashes == ["waits"])
        #expect(extensions.checks.gated.isEmpty)
        #expect(!extensions.hasBeforeStartHooks)
        #expect(extensions.summary(of: torrent("held")).isEmpty)
        // Remembered, with each extension still on underneath.
        let reopened = sandbox.registry()
        #expect(!reopened.isOn)
        #expect(reopened.isEnabled(reopened.named("fake-download-check")!))

        extensions.setOn(true)
        #expect(extensions.hasBeforeStartHooks)
        #expect(sandbox.registry().isOn)
    }

    @Test func hooksRunWhenADownloadFinishesEvenBetweenRefreshes() async throws {
        let sandbox = try ExtensionSandbox()
        let started = Started()
        let extensions = coordinator(sandbox, files: ["Tool/setup.exe"], started: started)
        try extensions.registry.loadDevelopment(from: try sandbox.makeExtension("scanner", event: "afterFinish"))
        let later = Date.now.addingTimeInterval(60)

        // Already finished at launch, before it was turned on: left alone.
        extensions.observe([torrent("old", progress: 1, completedOn: .now.addingTimeInterval(-3600))])
        // Finishes while OrbTorrent watches.
        extensions.observe([torrent("old", progress: 1, completedOn: .now.addingTimeInterval(-3600)), torrent("c1", state: "downloading", progress: 0.5)])
        extensions.observe([torrent("old", progress: 1, completedOn: .now.addingTimeInterval(-3600)), torrent("c1", state: "stalledUP", progress: 1, completedOn: later),
                            // New to the library and already finished.
                            torrent("c2", state: "stalledUP", progress: 1, completedOn: later)])
        await eventually { extensions.checks.records(for: "c1").first?.status == .passed && extensions.checks.records(for: "c2").first?.status == .passed }
        #expect(extensions.checks.records(for: "c1").map(\.status) == [.passed])
        #expect(extensions.checks.records(for: "c2").map(\.status) == [.passed])
        #expect(extensions.checks.records(for: "old").isEmpty)

        // Checking its files again, or brought over from another app, it
        // finishes again with the date it first finished: not a new finish.
        let c1 = torrent("c1", state: "stalledUP", progress: 1, completedOn: later)
        let c2 = torrent("c2", state: "stalledUP", progress: 1, completedOn: later)
        extensions.observe([torrent("old", state: "checkingUP", progress: 0.2, completedOn: .now.addingTimeInterval(-3600)), c1, c2])
        extensions.observe([torrent("old", progress: 1, completedOn: .now.addingTimeInterval(-3600)), c1, c2])
        try await Task.sleep(for: .milliseconds(300))
        #expect(extensions.checks.records(for: "old").isEmpty)

        // Removed downloads' results are forgotten.
        extensions.observe([torrent("c1", state: "stalledUP", progress: 1, completedOn: later)])
        #expect(extensions.checks.records(for: "c2").isEmpty)
    }

    final class Library: @unchecked Sendable {
        var files: [TorrentFile] = []
    }

    func file(_ index: Int, wanted: Bool = true, done: Bool) -> TorrentFile {
        TorrentFile(index: index, name: "Pack/\(index).exe", size: 10, progress: done ? 1 : 0,
                    priority: wanted ? .normal : .skip, availability: 1)
    }

    @Test func choosingMoreFilesRunsHooksAgainWithTheNewOnesMarked() async throws {
        let sandbox = try ExtensionSandbox()
        let extensions = Extensions(registry: sandbox.registry(), settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        let script = """
        var __orbExtension = { default: (download) => ({ status: "failed", files: [{ file: 0, status: "failed" }],
          summary: "New: " + download.files.filter((file) => file.isNew).map((file) => file.index).join(",") }) };
        """
        try extensions.registry.loadDevelopment(from: try sandbox.makeExtension("scanner", event: "afterFinish", script: script))
        let library = Library()
        extensions.files = { _ in library.files }
        let flagged = Started()
        extensions.onFlagged = { torrent, _ in flagged.hashes.append(torrent.hash) }

        // Only the first file is chosen, and it finishes.
        library.files = [file(0, done: true), file(1, wanted: false, done: false)]
        extensions.observe([torrent("e1", state: "downloading", progress: 0.5)])
        extensions.observe([torrent("e1", state: "stalledUP", progress: 1, completedOn: .now)])
        await eventually { extensions.checks.records(for: "e1").first?.status == .failed }
        #expect(extensions.checks.records(for: "e1").first?.summary == "New: 0")
        #expect(flagged.hashes == ["e1"])

        // The user chooses the second file too, which finishes later. The
        // engine forgets when it first finished.
        library.files = [file(0, done: true), file(1, done: false)]
        extensions.observe([torrent("e1", state: "downloading", progress: 0.5)])
        library.files = [file(0, done: true), file(1, done: true)]
        extensions.observe([torrent("e1", state: "stalledUP", progress: 1, completedOn: .now)])
        await eventually { extensions.checks.records(for: "e1").first?.summary == "New: 1" }
        #expect(extensions.checks.records(for: "e1").first?.summary == "New: 1")
        #expect(extensions.checks.records(for: "e1").first?.seenFiles == [0, 1])
        // It flagged the same file the user was already told about.
        #expect(flagged.hashes == ["e1"])
    }

    /// A report on the checks: what each found, and whether one holds the download.
    static let reporter = """
    var __orbExtension = { default: (download) => ({ status: "passed", summary: download.checks.map((check) =>
      check.extension.name + ":" + check.status + ":" + (check.files || []).map((file) => file.path).join("|")).join(",")
      + ";held=" + download.isHeld + ";new=" + download.files.filter((file) => file.isNew).length }) };
    """

    @Test func reportsHearWhatTheChecksFoundOnceTheyreDone() async throws {
        let sandbox = try ExtensionSandbox()
        let extensions = Extensions(registry: sandbox.registry(), settings: sandbox.settings(),
                                    checks: ChecksStore(file: sandbox.root.appending(path: "checks.json")), runner: .bundled)
        let scanner = "var __orbExtension = { default: () => ({ status: \"failed\", summary: \"Bad\", files: [{ file: 1, status: \"failed\" }] }) };"
        try extensions.registry.loadDevelopment(from: try sandbox.makeExtension("scanner", event: "afterFinish", script: scanner))
        try extensions.registry.loadDevelopment(from: try sandbox.makeExtension("reporter", event: "afterChecks", script: Self.reporter))
        let library = Library()
        library.files = [file(0, done: true), file(1, done: true)]
        extensions.files = { _ in library.files }

        extensions.observe([torrent("r1", state: "downloading", progress: 0.5)])
        let finished = torrent("r1", state: "stalledUP", progress: 1, completedOn: .now)
        extensions.observe([finished])
        await eventually { extensions.checks.record("reporter/check", for: "r1")?.status == .passed }
        #expect(extensions.checks.record("reporter/check", for: "r1")?.summary == "scanner:failed:Pack/1.exe;held=false;new=2")
        // A report isn't a check, so it's kept apart from them.
        #expect(extensions.summary(of: finished).records.map(\.extensionName) == ["scanner"])
        #expect(extensions.reports(of: finished).records.map(\.extensionName) == ["reporter"])
        #expect(extensions.checks.badge(for: "r1") == .failed)
    }

    @Test func reportsHearWhenACheckHoldsADownload() async throws {
        let sandbox = try ExtensionSandbox(officialExtensions: ["fake-download-check"])
        let started = Started()
        let extensions = coordinator(sandbox, files: ["Film/Film.2024.1080p.mp4.exe"], started: started)
        try extensions.registry.loadDevelopment(from: try sandbox.makeExtension("reporter", event: "afterChecks", script: Self.reporter))
        extensions.gate("h1")
        extensions.observe([torrent("h1")])
        await eventually { extensions.checks.record("reporter/check", for: "h1")?.status == .passed }
        #expect(extensions.checks.gate(for: "h1") == .held)
        #expect(extensions.checks.record("reporter/check", for: "h1")?.summary
            == "fake-download-check:failed:Film/Film.2024.1080p.mp4.exe;held=true;new=0")
    }
}

struct FingerprintsTests {
    @Test func aFileIsReadAgainOnlyOnceItChanges() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-fingerprint-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        let then = Date(timeIntervalSince1970: 1_700_000_000)
        try Data("hello".utf8).write(to: file)
        try FileManager.default.setAttributes([.modificationDate: then], ofItemAtPath: file.path)
        let fingerprints = Fingerprints()
        let hello = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        #expect(try await fingerprints.sha256(of: file) == hello)

        // Changed in place to the same size, with its time put back: taken as
        // the same file, so it isn't read again.
        let handle = try FileHandle(forWritingTo: file)
        try handle.write(contentsOf: Data("jello".utf8))
        try handle.close()
        try FileManager.default.setAttributes([.modificationDate: then], ofItemAtPath: file.path)
        #expect(try await fingerprints.sha256(of: file) == hello)

        // Modified since: read again.
        try FileManager.default.setAttributes([.modificationDate: then.addingTimeInterval(60)], ofItemAtPath: file.path)
        #expect(try await fingerprints.sha256(of: file) != hello)
    }
}

/// Build an Extension → With AI: what the Develop tab gives people to paste into their coding agent.
struct AgentPromptTests {
    @Test func saysWhatToBuildAndEveryStepAnAgentTakes() {
        let prompt = AgentPrompt.text(for: "  Hold downloads that contain .scr files.\n", isDevelopment: false)
        #expect(prompt.hasPrefix("Build an OrbTorrent extension for me. What it should do: Hold downloads that contain .scr files.\n"))
        for command in ["npm create @orbtorrent/extension@latest", "AGENTS.md", "npx orb doctor", "npx orb downloads", "npx orb run", "npx orb install"] {
            #expect(prompt.contains(command), "missing \(command)")
        }
        #expect(prompt.contains("If what I asked for needs something extensions can't do, tell me before you build it."))
        #expect(!prompt.contains("ORB_APP"))
        #expect(!prompt.contains("\n\n\n"))
    }

    @Test func pointsAgentsAtOrbTorrentDevFromIt() {
        #expect(AgentPrompt.text(for: "Anything", isDevelopment: true).contains("put `ORB_APP=dev` before every `npx orb` command"))
    }
}
