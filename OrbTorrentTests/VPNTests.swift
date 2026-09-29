import Foundation
import Testing
@testable import OrbTorrent

@MainActor
struct VPNTests {
    private let proton = VPNMonitor.Connection(serviceID: "p", name: "ProtonVPN", interface: "utun4",
                                               address: "10.2.0.2", router: "10.2.0.1")

    @Test func recognisesTunnelInterfaces() {
        for tunnel in ["utun4", "ipsec0", "ppp0", "wg0", "tun1", "gpd0"] {
            #expect(VPNMonitor.isTunnel(tunnel), "\(tunnel)")
        }
        for plain in ["en0", "en7", "bridge100", "lo0", "awdl0"] {
            #expect(!VPNMonitor.isTunnel(plain), "\(plain)")
        }
    }

    @Test func notesRouteChangesThatCanMoveInternetTraffic() {
        func message(type: Int32, flags: Int32) -> [UInt8] {
            [92, 0, 5, UInt8(type), 4, 0, 0, 0] + withUnsafeBytes(of: flags.littleEndian, Array.init)
        }
        // wg-quick and OpenVPN adding 0.0.0.0/1 through a tunnel, and taking it away.
        #expect(VPNMonitor.changesRouting(message(type: RTM_ADD, flags: RTF_UP | RTF_STATIC)))
        #expect(VPNMonitor.changesRouting(message(type: RTM_DELETE, flags: RTF_UP | RTF_STATIC)))
        #expect(VPNMonitor.changesRouting(message(type: RTM_NEWADDR, flags: 0)))
        // A route cloned for one peer, and a link-layer entry for the router.
        #expect(!VPNMonitor.changesRouting(message(type: RTM_ADD, flags: RTF_UP | RTF_HOST | RTF_WASCLONED)))
        #expect(!VPNMonitor.changesRouting(message(type: RTM_DELETE, flags: RTF_HOST | RTF_LLINFO)))
        #expect(!VPNMonitor.changesRouting(message(type: RTM_IFINFO, flags: 0)))
        #expect(!VPNMonitor.changesRouting([92, 0]))
    }

    @Test func usesAnyConnectionWhenTheSettingIsOff() {
        #expect(VPNBinding.interface(vpnOnly: false, connection: proton) == "")
        #expect(VPNBinding.interface(vpnOnly: false, connection: nil) == "")
    }

    @Test func usesOnlyTheVPNWhenOn() {
        #expect(VPNBinding.interface(vpnOnly: true, connection: proton) == "utun4")
    }

    @Test func usesNoConnectionAtAllWithoutTheVPN() {
        #expect(VPNBinding.interface(vpnOnly: true, connection: nil) == VPNBinding.noVPN)
    }

    @Test func dropsConnectionsThatCouldOutliveTheMove() {
        // Turning the setting on, with or without the VPN connected.
        #expect(VPNBinding.leavesStrayConnections(movingFrom: "", to: "utun4"))
        #expect(VPNBinding.leavesStrayConnections(movingFrom: "", to: VPNBinding.noVPN))
        // The VPN dropping, or another VPN taking over.
        #expect(VPNBinding.leavesStrayConnections(movingFrom: "utun4", to: VPNBinding.noVPN))
        #expect(VPNBinding.leavesStrayConnections(movingFrom: "utun4", to: "utun5"))
    }

    @Test func keepsConnectionsWhenNothingCouldLeak() {
        // Nothing connected yet, or any network now allowed.
        #expect(!VPNBinding.leavesStrayConnections(movingFrom: VPNBinding.noVPN, to: "utun4"))
        #expect(!VPNBinding.leavesStrayConnections(movingFrom: nil, to: "utun4"))
        #expect(!VPNBinding.leavesStrayConnections(movingFrom: "utun4", to: ""))
    }

    @Test func onlyRunningDownloadsHavePeersToDrop() {
        for state in [TorrentState.downloading, .stalledDL, .uploading, .stalledUP, .metaDL, .forcedDL] {
            #expect(state.mayHavePeers, "\(state)")
        }
        for state in [TorrentState.stoppedDL, .stoppedUP, .queuedDL, .checkingUP, .moving, .error] {
            #expect(!state.mayHavePeers, "\(state)")
        }
    }

    @Test func aFullDiskIsSaidBeforeAMissingVPN() {
        #expect(StatusProblem.current(fullDisks: ["Disk"], vpn: .waitingForVPN, vpnName: nil, connection: .offline)
            == .diskAlmostFull(["Disk"]))
    }

    @Test func aMissingVPNExplainsBeingOffline() {
        #expect(StatusProblem.current(fullDisks: [], vpn: .waitingForVPN, vpnName: "ProtonVPN", connection: .offline)
            == .waitingForVPN("ProtonVPN"))
    }

    @Test func throughTheVPNOnlyConnectionProblemsShow() {
        #expect(StatusProblem.current(fullDisks: [], vpn: .through(proton), vpnName: nil, connection: nil) == nil)
        #expect(StatusProblem.current(fullDisks: [], vpn: .through(proton), vpnName: nil, connection: .incomingBlocked)
            == .connection(.incomingBlocked))
    }
}
