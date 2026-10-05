import Foundation
import Testing
@testable import OrbTorrent

struct ReleaseNameTests {
    private func read(_ name: String) throws -> ReleaseName {
        try #require(ReleaseName(name))
    }

    @Test func readsAnEpisode() throws {
        let name = try read("Orbit.Station.S02E01.1080p.WEB.H264-GROUP.mkv")
        #expect(name.title == "Orbit Station")
        #expect(name.seasons == [2])
        #expect(name.episodes == [1])
        #expect(name.episodeTitle == nil)
    }

    @Test func readsASeasonPack() throws {
        let name = try read("Orbit.Station.S02.2160p.WEB-DL.x265.10bit.HDR.DDP5.1-GROUP")
        #expect(name.title == "Orbit Station")
        #expect(name.seasons == [2])
        #expect(name.episodes.isEmpty)
        #expect(try read("Show.Name.S01-S03.1080p.BluRay.x264-GROUP").seasons == [1, 2, 3])
    }

    @Test func readsAFilmAndItsYear() throws {
        let name = try read("Sintel.2010.2160p.UHD.BluRay.HDR10.x265-GROUP")
        #expect(name.title == "Sintel")
        #expect(name.year == 2010)
        #expect(try read("Big Buck Bunny (2008) 1080p WEB-DL").title == "Big Buck Bunny")
    }

    @Test func keepsANumberThatsPartOfTheTitle() throws {
        #expect(try read("Orbit.2049.2017.2160p.BluRay.x265").title == "Orbit 2049")
        #expect(try read("Summer.1984.2020.1080p.WEB-DL").title == "Summer 1984")
        let film = try read("1999.2019.1080p.BluRay.x264")
        #expect(film.title == "1999")
        #expect(film.year == 2019)
        #expect(try read("Some Film (1999) Making Of 1996 720p").year == 1999)
    }

    @Test func leavesOutAWebsiteOrGroupBeforeTheName() throws {
        #expect(try read("www.example.org - Sintel (2010) 1080p WEB-DL - 2GB.mkv").title == "Sintel")
        #expect(try read("[www.example.org] Some Film 2021 720p").title == "Some Film")
    }

    @Test func readsAnimeEpisodes() throws {
        let name = try read("[Group] Some Anime - 12 (1080p) [5A493522].mkv")
        #expect(name.title == "Some Anime")
        #expect(name.absoluteEpisode == 12)
        let seasoned = try read("[Group] Series Title! S2 - 07 [720p].mkv")
        #expect(seasoned.title == "Series Title!")
        #expect(seasoned.seasons == [2])
        #expect(seasoned.episodes == [7])
        #expect(try read("Series Title (2014) - 39 [720p]").absoluteEpisode == 39)
    }

    @Test func readsSeveralEpisodes() throws {
        #expect(try read("Show.Name.S01E01-03.720p.HDTV").episodes == [1, 2, 3])
        #expect(try read("Show.Name.S01E01E02.720p.HDTV").episodes == [1, 2])
        #expect(try read("Show.Name.S01E02.S01E03.HDTV.XviD").episodes == [2, 3])
        #expect(try read("Show Name - 1x02-03 - Title").episodes == [2, 3])
    }

    @Test func aNumberInAnEpisodesTitleIsntAnotherEpisode() throws {
        let name = try read("Show Name - S02E21 - 94 Days - 720p.mkv")
        #expect(name.episodes == [21])
        #expect(name.episodeTitle == "94 Days")
        #expect(try read("Show Name - 10x12 - 24 Hour Day [SDTV]").episodes == [12])
        #expect(try read("ShowName-S12E13-3_Acts.mkv").episodes == [13])
    }

    @Test func readsOtherWaysOfNumberingEpisodes() throws {
        let code = try read("the.show.2014.208.hdtv.mkv")
        #expect(code.title == "the show")
        #expect(code.seasons == [2])
        #expect(code.episodes == [8])
        let words = try read("Show Name Season 2 Episode 5 720p")
        #expect(words.seasons == [2])
        #expect(words.episodes == [5])
        let daily = try read("The.Evening.News.2026.10.05.Guest.Name.1080p.WEB")
        #expect(daily.title == "The Evening News")
        #expect(daily.date == DateComponents(year: 2026, month: 10, day: 5))
        // The number before "Sezon" is the season, so this isn't season 7.
        #expect(ReleaseName("Dizi.2.Sezon.7.Bolum.2021.1080p.WEB-DL")?.seasons.contains(7) != true)
    }

    @Test func keepsInitials() throws {
        #expect(try read("Agents.of.N.O.V.A.S02E01.1080p.WEB-DL").title == "Agents of N.O.V.A")
        #expect(try read("The.Crew.from.O.R.B.I.T.2015.1080p.BluRay").title == "The Crew from O.R.B.I.T")
    }

    @Test func readsThePicturesQuality() throws {
        #expect(try read("Orbit.Station.S02.2160p.WEB-DL.x265.10bit.HDR.DDP5.1-GROUP").quality == "4K HDR")
        #expect(try read("Some Film (2026) 2160p 4K SDR WEB-DL").quality == "4K")
        #expect(try read("Some.Film.2021.DV.2160p.WEB-DL.x265").quality == "4K HDR")
        #expect(try read("Some.Film.2017.UHD.BluRay.HDR10+.x265").quality == "4K HDR")
        #expect(try read("Some Film (1996) Blu-Ray 1080p24 H.264").quality == "1080p")
        #expect(try read("[Group] Some Anime - 01 (1280x720 HEVC AAC)").quality == "720p")
        #expect(try read("Show.Name.S01E01.1080i.HDTV").quality == "1080i")
        // "HDRip" is a kind of copy, not HDR.
        #expect(try read("Some.Film.2016.720p.HDRip.x264").quality == "720p")
        // "4K" in a title isn't its quality.
        #expect(try read("4K.Wonders.2020.1080p.WEB-DL").quality == "1080p")
        #expect(try read("Some.Film.2010.BluRay.x264").quality == nil)
    }

    @Test func leavesNamesThatArentReleaseNamesAsTheyAre() {
        #expect(ReleaseName("ubuntu-26.04-desktop-amd64.iso") == nil)
        #expect(ReleaseName("archlinux-2026.10.01-x86_64.iso") == nil)
        #expect(ReleaseName("LibreOffice_26.8_MacOS_aarch64.dmg") == nil)
        #expect(ReleaseName("Apollo 11 Mission Audio") == nil)
        #expect(ReleaseName("Holiday Photos") == nil)
        // A title and tags alone aren't enough.
        #expect(ReleaseName("[h265 - hevc] some film 2 1080p french ac3") == nil)
        // Nothing before the episode to call a title.
        #expect(ReleaseName("5x09 - 100 [720p WEB-DL].mkv") == nil)
    }
}
