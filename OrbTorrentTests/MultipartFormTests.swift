import Foundation
import Testing
@testable import OrbTorrent

/// The form a torrent file is sent to the engine in.
struct MultipartFormTests {
    /// A file name can't end its header and add fields of its own.
    @Test func aFileNameCantBreakOutOfItsHeader() throws {
        var form = MultipartForm()
        form.addFile("torrents", filename: "Sintel\r\nContent-Disposition: form-data; name=\"savepath\"\r\n\r\n/tmp\n\".torrent",
                     contentType: "application/x-bittorrent", data: Data("d4:infodee".utf8))
        let body = try #require(String(data: form.finalized(), encoding: .utf8))
        let header = try #require(body.components(separatedBy: "\r\n").first { $0.hasPrefix("Content-Disposition") })
        #expect(header == "Content-Disposition: form-data; name=\"torrents\"; filename=\"SintelContent-Disposition: form-data; name='savepath'/tmp'.torrent\"")
        #expect(body.components(separatedBy: "\r\n").filter { $0.hasPrefix("Content-Disposition") }.count == 1)
    }

    @Test func anOrdinaryFileNameIsKept() throws {
        var form = MultipartForm()
        form.addFile("torrents", filename: "Big Buck Bunny.torrent", contentType: "application/x-bittorrent", data: Data())
        let body = try #require(String(data: form.finalized(), encoding: .utf8))
        #expect(body.contains("filename=\"Big Buck Bunny.torrent\"\r\n"))
    }
}
