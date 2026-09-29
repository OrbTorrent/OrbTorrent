import Foundation
import Testing
@testable import OrbTorrent

struct ModelDecodingTests {
    @Test func decodesTorrentFromEngineResponse() throws {
        // Trimmed from qBittorrent 5.2.3's GET /api/v2/torrents/info.
        let json = """
        [{"added_on":1790100000,"amount_left":0,"completion_on":1790100500,"content_path":"/Users/me/Downloads/Big Buck Bunny",
          "dlspeed":0,"downloaded":289823516,"eta":8640000,"f_l_piece_prio":false,"hash":"dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c",
          "magnet_uri":"magnet:?xt=urn:btih:dd82","name":"Big Buck Bunny","num_complete":12,"num_incomplete":3,"num_leechs":1,
          "num_seeds":0,"progress":1,"ratio":0.01,"save_path":"/Users/me/Downloads","seq_dl":false,"size":289823516,
          "state":"stalledUP","total_size":289823516,"upspeed":0,"uploaded":1024,"some_new_field":{"ignored":true}}]
        """
        let torrents = try JSONDecoder().decode([Torrent].self, from: Data(json.utf8))
        let torrent = try #require(torrents.first)
        #expect(torrent.name == "Big Buck Bunny")
        #expect(torrent.state == .stalledUP)
        #expect(torrent.state.activity == .seeding)
        #expect(torrent.isComplete)
        #expect(torrent.swarmSeeds == 12)
        #expect(torrent.addedOn != nil)
    }

    @Test func mapsLegacyPausedStates() throws {
        let states = try JSONDecoder().decode([TorrentState].self, from: Data(#"["pausedDL","pausedUP","somethingNew"]"#.utf8))
        #expect(states == [.stoppedDL, .stoppedUP, .unknown])
    }

    @Test func foldsFilePrioritiesIntoFourLevels() throws {
        let priorities = try JSONDecoder().decode([FilePriority].self, from: Data("[0,1,4,6,7]".utf8))
        #expect(priorities == [.skip, .normal, .normal, .high, .maximum])
    }

    @Test func treatsPeerSourcesSeparatelyFromTrackers() throws {
        let json = #"[{"url":"** [DHT] **","status":2,"tier":"","num_peers":40,"num_seeds":-1},{"url":"udp://tracker.example:1337/announce","status":4,"tier":0,"msg":"Timed out"}]"#
        let trackers = try JSONDecoder().decode([Tracker].self, from: Data(json.utf8))
        #expect(trackers[0].isPeerSource)
        #expect(trackers[0].displayName == "DHT")
        #expect(trackers[0].seeds == 0)
        #expect(!trackers[1].isPeerSource)
        #expect(trackers[1].displayName == "tracker.example")
        #expect(trackers[1].status == .notWorking)
    }

    @Test func formatsEtaAndPercentSafely() {
        #expect(Format.eta(8_640_000) == nil)
        #expect(Format.eta(0) == nil)
        #expect(Format.percent(0.9996) != "100%")
        #expect(Format.percent(1) == "100%")
    }
}
