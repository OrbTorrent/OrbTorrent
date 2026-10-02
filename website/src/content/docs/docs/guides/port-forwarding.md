---
title: Port forwarding
description: Let other peers connect to you, for faster downloads, through your router or your VPN, and check that it's working.
---

A torrent downloads faster with more peers. You can always connect to other peers, but they can only connect to you if your **port** is open to them. With an open port you reach peers that are themselves behind closed ports, which matters most for downloads with few people sharing them.

## At home: your router

OrbTorrent opens its port on your router by itself, with UPnP or NAT-PMP, which most home routers support.

In **Settings › Network › Connection**:

| | |
|---|---|
| **Status** | **Reachable by peers** when your port is open, **Incoming connections blocked** when it isn't, or **Offline**. |
| **Listening port** | The port OrbTorrent listens on. **Random** picks a new one. |
| **Open the port on my router automatically (UPnP / NAT-PMP)** | On unless you turn it off. |

If it says **Incoming connections blocked**:

- Make sure **UPnP** or **NAT-PMP** is turned on in your router's settings, or forward the listening port to your Mac by hand there.
- Your internet provider may use **carrier-grade NAT**, which shares one public address between many customers, so no port can be opened. Ask them for a public IP address, or use a VPN that forwards ports.

Downloads still work while incoming connections are blocked. Some peers still reach you through µTP hole punching, and the **Peers** tab counts them as **incoming**.

## Through a VPN

Your router's port is no use through a VPN: the VPN has to forward a port to you. While you [download only through a VPN](/docs/guides/vpn), OrbTorrent gets the VPN's forwarded port, listens on it, and keeps it in step as it changes. It looks, in order:

1. **A port you've entered.** Some VPNs, such as **AirVPN** and **Windscribe**, have you reserve a port in your account. Enter it once in **Forwarded port**, in **Settings › Network › VPN**.
2. **Your VPN's gateway, over NAT-PMP.** Many VPNs forward a port to anyone who asks this way. Some only do once you turn port forwarding on in their app, or connect to a server that allows peer-to-peer traffic, which can need a paid plan.
3. **Private Internet Access's app.** Turn on port forwarding in its settings, and OrbTorrent reads the port from it.

While a port is forwarded, your own listening port and the router setting are set aside, and the **Connection** section shows which port is in use and who forwards it. They come back when you stop downloading through the VPN.

### Check it's working

In **Settings › Network › VPN**, **Incoming connections** says:

| | |
|---|---|
| **Port 51234** | "Forwarded by …, so peers can connect to you." It's working. |
| **Looking for a forwarded port…** | OrbTorrent is asking. It takes a few seconds after the VPN connects. |
| **No port forwarded** | "Only peers with open ports can connect to you." The VPN didn't forward one. |

A forwarded port lasts a minute at a time, and OrbTorrent renews it every 45 seconds. If your VPN gives you a new port, after reconnecting or changing server, OrbTorrent moves to it by itself.

### If no port is forwarded

- **Check your VPN forwards ports at all.** Not every VPN does, and some only on certain plans or servers.
- **Turn port forwarding on in your VPN's app,** if it has the setting, then reconnect.
- **If your VPN reserves a port in your account,** enter it in **Forwarded port**.
- **Leave Forwarded port empty** for VPNs that hand out ports themselves: it says **Automatic**.

Downloads still work without a forwarded port. They just reach fewer peers.
