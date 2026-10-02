---
title: Download only through a VPN
description: A kill switch for your downloads. Tie OrbTorrent to your VPN, so downloading and sharing stop if the VPN drops instead of carrying on without it.
---

Peers and trackers can see the IP address you download from. A VPN gives them its address instead of yours, but if the VPN drops, most torrent apps carry on over your normal connection without saying so.

**Only download through a VPN** ties OrbTorrent to your VPN's connection. If the VPN drops, downloading and sharing stop, and they continue once it's back.

## Turn it on

1. Open **Settings › Network**.
2. Turn on **Only download through a VPN**.
3. Choose your VPN under **VPN**, or leave it on **Any VPN**.

**Any VPN** means any VPN that carries all your internet traffic. A VPN that only reaches some addresses, such as one for your office or your own devices, doesn't count. If you use more than one, choose the one to download through.

Turning it on while downloads are running drops their connections, and they reconnect through the VPN.

## What you'll see

- **In Settings › Network,** the VPN's status: **Connected through …** in green, or **Not connected, so nothing is downloading** in orange.
- **In the menu bar panel and the window's sidebar,** "Through …" with a green shield, while downloads go through the VPN.
- **When the VPN isn't connected,** the sidebar says **Waiting for …**, the orb turns amber, and nothing downloads or shares over your normal connection.

New magnet links wait too: their file lists arrive once the VPN connects.

## Which VPNs work

OrbTorrent finds VPNs in two ways, so most work with nothing to set up:

- **VPN apps** that add their VPN to your Mac's network settings, which is how most VPN apps on the Mac work.
- **Tunnels that route all your traffic** without being in your network settings, such as **Tunnelblick**, WireGuard's **`wg-quick`**, and **Private Internet Access** with OpenVPN. OrbTorrent finds these from your Mac's routes.

It notices within moments when a VPN connects or drops, including after your Mac sleeps, or when Wi-Fi drops and comes back.

## A kill switch, just for downloads

Many VPN apps have a kill switch, which cuts off your whole Mac's internet if the VPN drops. **Only download through a VPN** is one for OrbTorrent alone:

- **It works with any VPN,** including ones whose app has no kill switch, or one you've turned off.
- **The rest of your Mac stays online** while the VPN reconnects. Only downloading and sharing wait.
- **It follows the VPN** when it reconnects or your Mac wakes, with nothing to choose again.

You can use both: a VPN app's kill switch doesn't get in OrbTorrent's way.

## Faster downloads through a VPN

Through a VPN, other peers can only connect to you if the VPN **forwards a port** to you. Without one, you can still connect to them, and downloads work, but you reach fewer peers. OrbTorrent picks up a forwarded port by itself from many VPNs, and keeps it in step as it changes. [Port forwarding](/docs/guides/port-forwarding) explains.

## How it works

OrbTorrent's download engine is bound to the VPN's network connection, so it can't use any other. If the VPN goes away, the engine has nothing to connect through, rather than falling back to your normal connection. The engine starts already bound to the VPN, so it never sends anything first over another connection.

The rest of OrbTorrent, such as checking for updates, isn't tied to the VPN, and uses whichever connection your Mac is using. [Privacy](/docs/guides/privacy) lists what it connects to.

## If it says it isn't connected

- **Check the VPN is connected,** in its app or in **System Settings › VPN**.
- **If you chose a VPN,** make sure it's the one that's connected, or choose **Any VPN**.
- **If it's a tunnel that only routes some addresses,** such as a split tunnel, **Any VPN** won't use it. Route all traffic through it, or choose it by name if it's in your network settings.

[Troubleshooting](/docs/help/troubleshooting#it-says-waiting-for-vpn) has more.
