import Foundation
import Testing
@testable import OrbTorrent

/// OrbTorrent and OrbTorrent Dev.
@MainActor
final class IdentityTests {
    @Test func devHasItsOwnName() {
        #expect(AppIdentity.name(for: "com.orbtorrent.mac") == "OrbTorrent")
        #expect(AppIdentity.name(for: "com.orbtorrent.mac.dev") == "OrbTorrent Dev")
        #expect(!AppIdentity.isDevelopment("com.orbtorrent.mac"))
    }

    /// Tests run inside OrbTorrent Dev, never touching OrbTorrent's library or Keychain items.
    @Test func testsRunInsideDev() {
        #expect(AppIdentity.isDevelopment)
        #expect(EnginePaths.support.lastPathComponent == "OrbTorrent Dev")
        #expect(ExtensionSettings.service(for: "virustotal") == "com.orbtorrent.mac.dev.extension.virustotal")
    }
}
