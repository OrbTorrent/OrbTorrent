import Foundation
import Testing
@testable import OrbTorrent

struct ShownNamesTests {
    @Test func showsADownloadByWhatItIs() {
        #expect(ShownNames.download("Orbit.Station.S02.2160p.WEB-DL.x265.10bit.HDR.DDP5.1-GROUP") == "Orbit Station · Season 2")
        #expect(ShownNames.download("Orbit.Station.S02E01.1080p.WEB.H264-GROUP.mkv") == "Orbit Station · S02E01")
        #expect(ShownNames.download("Show.Name.S01E01-03.720p.HDTV") == "Show Name · S01E01–E03")
        #expect(ShownNames.download("Show.Name.S01-S03.1080p.BluRay.x264") == "Show Name · Seasons 1–3")
        #expect(ShownNames.download("Sintel.2010.2160p.UHD.BluRay.x265-GROUP") == "Sintel (2010)")
        #expect(ShownNames.download("[Group] Some Anime - 12 (1080p) [5A493522].mkv") == "Some Anime · Episode 12")
        // Anything else shows as it is.
        #expect(ShownNames.download("ubuntu-26.04-desktop-amd64.iso") == "ubuntu-26.04-desktop-amd64.iso")
    }

    @Test func showsASeasonsEpisodesByTheirNumbers() {
        let paths = [
            "Orbit.Station.S02/Orbit.Station.S02E02.1080p.WEB.H264-GROUP.mkv",
            "Orbit.Station.S02/Orbit.Station.S02E01.1080p.WEB.H264-GROUP.mkv",
            "Orbit.Station.S02/Other.Show.2x05.Some.Title.HDTV.XviD.avi",
            "Orbit.Station.S02/Orbit.Station.S02E03.Cold.Start.1080p.WEB.H264-GROUP.mkv",
            "Orbit.Station.S02/Orbit.Station.S02E01.en.srt",
            "Orbit.Station.S02/Read Me.txt",
        ]
        #expect(ShownNames.files(paths) == [
            "S02E02", "S02E01",
            // Another show's episode keeps its name.
            nil,
            "S02E03 · Cold Start",
            // So do subtitles, and everything else.
            nil, nil,
        ])
    }

    @Test func leavesOutTheWordsFilesInAFolderStartWith() {
        let paths = [
            "Course/Course.Name.Lecture.01.Intro.mp4",
            "Course/Course.Name.Lecture.02.Setup.mp4",
            "Course/Course.Name.Lecture.10.Wrap.Up.mp4",
            "Course/Course.Name.Notes.pdf",
        ]
        #expect(ShownNames.files(paths) == ["01.Intro.mp4", "02.Setup.mp4", "10.Wrap.Up.mp4", nil])
        // Not one word, or for fewer than three files.
        #expect(ShownNames.files(["Album/Track 1.mp3", "Album/Track 2.mp3", "Album/Track 3.mp3"]) == [nil, nil, nil])
        #expect(ShownNames.files(["A/Course.Name.Lecture.01.mp4", "A/Course.Name.Lecture.02.mp4"]) == [nil, nil])
    }

    @Test func copiesInDifferentQualitiesAreToldApartAndOthersShowTheirNames() {
        let library = ShownNames.Library([
            "Night.of.the.Living.Dead.1968.1080p.BluRay.x264",
            "Night.of.the.Living.Dead.1968.2160p.UHD.BluRay.x265",
            "Sintel.2010.1080p.BluRay.x264",
            "Sintel.2010.1080p.WEB-DL.x264",
        ])
        // A 1080p copy and a 4K copy: their badges tell them apart.
        #expect(!library.isShared("Night of the Living Dead (1968)", quality: "1080p", by: "Night.of.the.Living.Dead.1968.1080p.BluRay.x264"))
        #expect(library.hasOther("Night of the Living Dead (1968)", by: "Night.of.the.Living.Dead.1968.1080p.BluRay.x264"))
        // Two 1080p copies would look the same.
        #expect(library.isShared("Sintel (2010)", quality: "1080p", by: "Sintel.2010.1080p.BluRay.x264"))
        // One being added that's already in the library.
        #expect(library.isShared("Sintel (2010)", quality: "1080p", by: "Sintel.2010.1080p.AMZN.WEB-DL"))

        let files = ShownNames.files([
            "Show/Show.Name.S01E01.1080p.WEB.mkv",
            "Show/Show.Name.S01E01.2160p.WEB.mkv",
            "Show/Show.Name.S01E02.2160p.WEB.mkv",
            "Show/Show.Name.S01E03.1080p.WEB.mkv",
            "Show/Show.Name.S01E03.1080p.BluRay.mkv",
        ])
        #expect(files == ["S01E01 · 1080p", "S01E01 · 4K", "S01E02", nil, nil])
    }

    @Test func sortsByTheNameShown() {
        let bunny = Fixtures.torrent(hash: "a", name: "www.example.org - Big Buck Bunny (2008) 1080p", savePath: "/d", contentPath: "/d/a")
        let sintel = Fixtures.torrent(hash: "b", name: "Sintel.2010.2160p.BluRay", savePath: "/d", contentPath: "/d/b")
        // By the full names, "www.…" comes after "Sintel…"; as shown, "Big Buck Bunny (2008)" comes first.
        #expect(TorrentSort.name.areInIncreasingOrder(sintel, bunny))
        #expect(TorrentSort.name.areInIncreasingOrder(bunny, sintel, name: ShownNames.download))
    }
}
