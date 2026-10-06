import CommonCrypto
import Foundation
import Testing
@testable import OrbTorrent

struct EngineConfigurationTests {
    @Test func passwordHashMatchesQBittorrentFormat() throws {
        let hash = EngineConfiguration.passwordHash("correct horse battery staple")
        #expect(hash.hasPrefix("@ByteArray("))
        #expect(hash.hasSuffix(")"))

        let body = hash.dropFirst("@ByteArray(".count).dropLast()
        let parts = body.split(separator: ":")
        #expect(parts.count == 2)
        let salt = try #require(Data(base64Encoded: String(parts[0])))
        let key = try #require(Data(base64Encoded: String(parts[1])))
        #expect(salt.count == 16)
        #expect(key.count == 64)

        // Recompute PBKDF2-HMAC-SHA512 with 100 000 rounds, as qBittorrent does.
        var expected = [UInt8](repeating: 0, count: 64)
        let password = Array("correct horse battery staple".utf8)
        let status = password.withUnsafeBufferPointer { passwordBuffer in
            passwordBuffer.withMemoryRebound(to: CChar.self) { chars in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), chars.baseAddress, chars.count,
                                         saltBytes.bindMemory(to: UInt8.self).baseAddress, salt.count,
                                         CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512), 100_000,
                                         &expected, expected.count)
                }
            }
        }
        #expect(status == kCCSuccess)
        #expect(Data(expected) == key)
    }

    @Test func iniEditorAddsSectionsAndKeys() {
        var ini = IniFile(contents: "")
        ini.set("Accepted", "true", in: "LegalNotice")
        ini.set("WebUI\\Port", "1234", in: "Preferences")
        #expect(ini.contents == "[LegalNotice]\nAccepted=true\n\n[Preferences]\nWebUI\\Port=1234\n")
    }

    @Test func theEnginesDiskCacheStaysSmall() {
        let before = "[BitTorrent]\nSession\\DiskCacheSize=-1\nSession\\Port=6881\n"
        let after = EngineConfiguration.configured(before, for: EngineCredentials(port: 1234, username: "orbtorrent", password: "secret"))
        #expect(after.contains("[BitTorrent]\nSession\\DiskCacheSize=64\nSession\\Port=6881\n"))
    }

    @Test func iniEditorUpdatesInPlaceAndKeepsOtherSettings() {
        var ini = IniFile(contents: "[Preferences]\nWebUI\\Port=1\nGeneral\\Locale=en\n\n[BitTorrent]\nSession\\Port=6881\n")
        ini.set("WebUI\\Port", "2", in: "Preferences")
        ini.set("WebUI\\Address", "127.0.0.1", in: "Preferences")
        #expect(ini.contents == "[Preferences]\nWebUI\\Port=2\nGeneral\\Locale=en\nWebUI\\Address=127.0.0.1\n\n[BitTorrent]\nSession\\Port=6881\n")
    }
}
