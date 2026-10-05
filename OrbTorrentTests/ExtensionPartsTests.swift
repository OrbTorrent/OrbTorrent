import Foundation
import Testing
@testable import OrbTorrent

struct ExtensionManifestTests {
    static let virusTotal = """
    {
      "name": "virustotal", "title": "VirusTotal Scan", "description": "Checks finished downloads.",
      "author": "orbtorrent", "icon": "icon.png",
      "hooks": [{ "name": "scan", "title": "Scan with VirusTotal", "event": "afterFinish" }],
      "permissions": { "files": "contents", "network": ["www.VirusTotal.com"] },
      "preferences": [
        { "name": "apiKey", "type": "password", "title": "API key", "required": true },
        { "name": "scope", "type": "dropdown", "title": "Files to check", "default": "risky",
          "data": [{ "title": "Programs, archives and documents", "value": "risky" }, { "title": "All files", "value": "all" }] },
        { "name": "uploadUnknown", "type": "checkbox", "title": "Upload", "default": false }
      ],
      "verify": "verify",
      "orbtorrent": { "api": "1.0.0" }
    }
    """

    @Test func readsAManifest() throws {
        let manifest = try ExtensionManifest(data: Data(Self.virusTotal.utf8))
        #expect(manifest.name == "virustotal")
        #expect(manifest.hooks == [.init(name: "scan", title: "Scan with VirusTotal", description: nil, event: .afterFinish)])
        #expect(manifest.permissions.readsFileContents)
        #expect(manifest.permissions.network == ["www.virustotal.com"])
        #expect(manifest.preferences.map(\.kind) == [.password, .dropdown, .checkbox])
        #expect(manifest.preferences[0].isRequired)
        #expect(manifest.verify == "verify")
        #expect(manifest.apiVersion == "1.0.0")
        #expect(manifest.abilities == [
            "See the names and sizes of the files in your downloads",
            "Read the contents of your downloads",
            "Connect to www.virustotal.com",
        ])
    }

    @Test func listsEveryProblemAtOnce() {
        let json = """
        { "name": "Bad Name", "title": "", "hooks": [{ "name": "check", "event": "whenever" }],
          "permissions": { "network": ["https://example.com/api"] },
          "preferences": [{ "name": "key", "type": "password", "default": "secret" }] }
        """
        #expect(throws: ExtensionManifest.Invalid.self) { try ExtensionManifest(data: Data(json.utf8)) }
        do {
            _ = try ExtensionManifest(data: Data(json.utf8))
        } catch let invalid as ExtensionManifest.Invalid {
            #expect(invalid.problems.count == 7)
            #expect(invalid.problems.contains { $0.contains("lowercase letters, digits and hyphens") })
            #expect(invalid.problems.contains { $0.contains("“beforeStart”, “afterFinish” or “afterChecks”") })
            #expect(invalid.problems.contains { $0.contains("without https://") })
            #expect(invalid.problems.contains { $0.contains("can't have a default") })
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func knowsWhichAPIVersionsItCanRun() {
        #expect(ExtensionAPI.supports("1.0.0"))
        #expect(ExtensionAPI.supports("^1.0.0"))
        #expect(ExtensionAPI.supports("1.1.0"))
        #expect(ExtensionAPI.supports("1.2.0"))
        #expect(!ExtensionAPI.supports("1.3.0"))
        #expect(!ExtensionAPI.supports("2.0.0"))
    }
}

struct ExtensionNetworkTests {
    let network = ExtensionNetwork(extensionName: "virustotal",
                                   permissions: .init(readsFileContents: false, network: ["www.virustotal.com"]))

    @Test func onlyDeclaredHostsOverHTTPS() {
        #expect(network.refusal(for: URL(string: "https://www.virustotal.com/api/v3/files/abc")!) == nil)
        #expect(network.refusal(for: URL(string: "https://WWW.VIRUSTOTAL.COM/x")!) == nil)
        #expect(network.refusal(for: URL(string: "http://www.virustotal.com/x")!)?.message.contains("https://") == true)
        #expect(network.refusal(for: URL(string: "https://example.com/steal")!)?.message
            == "Request to example.com was refused. Add \"example.com\" to permissions.network in package.json.")
        #expect(network.refusal(for: URL(string: "https://user:pass@www.virustotal.com/")!) != nil)
        #expect(network.refusal(for: URL(string: "https://www.virustotal.com:8443/")!) != nil)
    }

    @Test func neverThisMacOrTheLocalNetwork() async {
        var rebound = network
        rebound.resolve = { _ in ["192.168.1.1"] }
        await #expect(throws: ExtensionRefusal.self) {
            try await rebound.perform(.init(url: URL(string: "https://www.virustotal.com/")!))
        }
    }

    @Test func tellsPublicAddressesFromLocalOnes() {
        for address in ["93.184.216.34", "1.1.1.1", "2606:4700:4700::1111", "::ffff:8.8.8.8"] {
            #expect(NetworkAddress.isPublic(address), "\(address)")
        }
        for address in ["127.0.0.1", "10.0.0.8", "172.16.4.1", "192.168.1.1", "169.254.1.1", "100.64.0.1", "0.0.0.0",
                        "224.0.0.1", "::1", "fe80::1%en0", "fd00::1", "::ffff:192.168.1.1", "2001:db8::1", "::", "not an address"] {
            #expect(!NetworkAddress.isPublic(address), "\(address)")
        }
    }
}

struct ExtensionServicesTests {
    let folder = FileManager.default.temporaryDirectory.appending(path: "orbtorrent-services-\(UUID().uuidString)")

    func services(readsFiles: Bool, files: [Int: URL] = [:], secrets: [String] = [],
                  log: @escaping @Sendable (String, String) -> Void = { _, _ in }) -> ExtensionServices {
        ExtensionServices(
            network: ExtensionNetwork(extensionName: "test", permissions: .init(readsFileContents: readsFiles, network: [])),
            files: files, storage: ExtensionStorage(file: folder.appending(path: "storage.json")),
            secrets: secrets, onProgress: { _ in }, onLog: log)
    }

    @Test func fingerprintsAFileOnlyWithPermission() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "a.txt")
        try Data("hello".utf8).write(to: file)

        let allowed = services(readsFiles: true, files: [0: file])
        #expect(try await allowed.handle(method: "files.sha256", params: ["file": 0])
            == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        await #expect(throws: ExtensionRefusal.self) { try await allowed.handle(method: "files.sha256", params: ["file": 1]) }
        await #expect(throws: ExtensionRefusal.self) {
            try await services(readsFiles: false, files: [0: file]).handle(method: "files.sha256", params: ["file": 0])
        }
    }

    @Test func storageKeepsValuesUpToALimit() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let services = services(readsFiles: false)
        _ = try await services.handle(method: "storage.set", params: ["key": "seen", "value": ["abc": 1]])
        #expect(try await services.handle(method: "storage.get", params: ["key": "seen"]) == ["abc": 1])
        #expect(try await services.handle(method: "storage.keys", params: [:]) == ["seen"])
        let big = JSONValue.string(String(repeating: "x", count: ExtensionStorage.limit))
        await #expect(throws: ExtensionRefusal.self) {
            try await services.handle(method: "storage.set", params: ["key": "big", "value": big])
        }
        _ = try await services.handle(method: "storage.remove", params: ["key": "seen"])
        #expect(try await services.handle(method: "storage.get", params: ["key": "seen"]) == .null)
    }

    @Test func secretsAreHiddenInLogs() {
        final class Box: @unchecked Sendable { var lines: [String] = [] }
        let box = Box()
        let services = services(readsFiles: false, secrets: ["sk-12345678"]) { _, message in box.lines.append(message) }
        services.log(level: "log", message: "Using key sk-12345678 for the lookup")
        #expect(box.lines == ["Using key ••• for the lookup"])
    }
}

struct MarkdownTextTests {
    @Test func joinsWrappedLinesAndKeepsListsApart() {
        let help = """
        ### Get a free API key

        1. Sign up at [virustotal.com](https://www.virustotal.com).
        2. Copy the key into **API key**
           and press **Verify**.

        The free key allows 4 lookups a minute and
        500 a day.
        - one
        - two
        """
        #expect(MarkdownText.blocks(of: help) == [
            .heading("Get a free API key"),
            .item(marker: "1.", text: "Sign up at [virustotal.com](https://www.virustotal.com)."),
            .item(marker: "2.", text: "Copy the key into **API key** and press **Verify**."),
            .paragraph("The free key allows 4 lookups a minute and 500 a day."),
            .item(marker: "•", text: "one"),
            .item(marker: "•", text: "two"),
        ])
    }
}
