import Testing
@testable import OrbTorrent

struct MagnetLinkTests {
    @Test func parsesHexInfoHashAndName() throws {
        let link = try #require(MagnetLink("magnet:?xt=urn:btih:DD8255ECDC7CA55FB0BBF81323D87062DB1F6D1C&dn=Big+Buck+Bunny"))
        #expect(link.infoHash == "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c")
        #expect(link.displayName == "Big Buck Bunny")
    }

    @Test func decodesPercentEncodedNames() throws {
        let link = try #require(MagnetLink("magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=C%2B%2B%20Book%20%5B2026%5D"))
        #expect(link.displayName == "C++ Book [2026]")
    }

    @Test func decodesBase32InfoHash() throws {
        // Base32 form of dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c.
        let link = try #require(MagnetLink("magnet:?xt=urn:btih:3WBFL3G4PSSV7MF37AJSHWDQMLNR63I4"))
        #expect(link.infoHash == "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c")
    }

    @Test func truncatesV2HashLikeQBittorrent() throws {
        let digest = String(repeating: "ab", count: 32)
        let link = try #require(MagnetLink("magnet:?xt=urn:btmh:1220\(digest)"))
        #expect(link.infoHash == String(digest.prefix(40)))
    }

    @Test func prefersV1HashInHybridLinks() throws {
        let v2 = String(repeating: "cd", count: 32)
        let link = try #require(MagnetLink(
            "magnet:?xt=urn:btmh:1220\(v2)&xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c"))
        #expect(link.infoHash == "dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c")
    }

    @Test func findsLinkInsideSurroundingText() throws {
        let text = "Try this: magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Test thanks"
        let link = try #require(MagnetLink.first(in: text))
        #expect(link.uri.hasSuffix("dn=Test"))
    }

    @Test func rejectsNonMagnetText() {
        #expect(MagnetLink("https://example.com") == nil)
        #expect(MagnetLink.first(in: "nothing to see") == nil)
    }
}
