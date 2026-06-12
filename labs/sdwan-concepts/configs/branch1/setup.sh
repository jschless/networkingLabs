#!/bin/sh
# branch1 — SD-WAN edge router for site 1 (the "vEdge/cEdge" of this site)
#
#   eth1  LAN1            10.1.0.1/24
#   eth2  MPLS transport  172.16.1.1/30   (color: mpls)
#   eth3  INET transport  198.51.100.1/30 (color: biz-internet)
#
#   tun-mpls  GRE over the MPLS transport   10.255.1.1/30
#   tun-inet  GRE over the internet         10.255.2.1/30
#
# Policy: DSCP EF (voice) rides tun-mpls; everything else rides tun-inet.
# pathmon.sh probes the MPLS tunnel and fails voice over to tun-inet.

# ── Interfaces ─────────────────────────────────────────────────────────────
ip link set eth1 up
ip addr add 10.1.0.1/24 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 172.16.1.1/30 dev eth2 2>/dev/null || true
ip link set eth3 up
ip addr add 198.51.100.1/30 dev eth3 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

# ── Underlay: reach branch2's transport addresses, per transport ──────────
ip route add 172.16.2.0/30   via 172.16.1.2   2>/dev/null || true   # via mpls-core
ip route add 198.51.100.4/30 via 198.51.100.2 2>/dev/null || true   # via inet-core

# ── Overlay tunnels (one per transport = one per "color") ─────────────────
ip tunnel add tun-mpls mode gre local 172.16.1.1 remote 172.16.2.1 ttl 64 2>/dev/null || true
ip link set tun-mpls up
ip addr add 10.255.1.1/30 dev tun-mpls 2>/dev/null || true

ip tunnel add tun-inet mode gre local 198.51.100.1 remote 198.51.100.5 ttl 64 2>/dev/null || true
ip link set tun-inet up
ip addr add 10.255.2.1/30 dev tun-inet 2>/dev/null || true

# ── Overlay routing (what OMP would advertise) ─────────────────────────────
# Default path for site-to-site traffic: the internet tunnel.
ip route add 10.2.0.0/24 via 10.255.2.2 2>/dev/null || true

# ── App-aware policy: voice (DSCP EF) prefers the MPLS path ───────────────
# Classify EF into fwmark 1, then policy-route mark 1 via table 100.
nft add table ip sdwan
nft 'add chain ip sdwan classify { type filter hook prerouting priority mangle; }'
nft 'add rule ip sdwan classify ip dscp ef meta mark set 1'
ip rule add fwmark 1 table 100 pref 100 2>/dev/null || true
ip route add 10.2.0.0/24 via 10.255.1.2 table 100 2>/dev/null || true

# ── Path monitor (the hand-rolled "BFD") ───────────────────────────────────
nohup sh /pathmon.sh > /var/log/pathmon.log 2>&1 &

echo "[branch1] Ready — LAN 10.1.0.0/24, tun-mpls 10.255.1.1, tun-inet 10.255.2.1"
