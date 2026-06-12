#!/bin/sh
# branch2 — SD-WAN edge router for site 2 (mirror of branch1)
#
#   eth1  LAN2            10.2.0.1/24
#   eth2  MPLS transport  172.16.2.1/30   (color: mpls)
#   eth3  INET transport  198.51.100.5/30 (color: biz-internet)
#
#   tun-mpls  10.255.1.2/30      tun-inet  10.255.2.2/30

# ── Interfaces ─────────────────────────────────────────────────────────────
ip link set eth1 up
ip addr add 10.2.0.1/24 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 172.16.2.1/30 dev eth2 2>/dev/null || true
ip link set eth3 up
ip addr add 198.51.100.5/30 dev eth3 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

# ── Underlay: reach branch1's transport addresses, per transport ──────────
ip route add 172.16.1.0/30   via 172.16.2.2   2>/dev/null || true   # via mpls-core
ip route add 198.51.100.0/30 via 198.51.100.6 2>/dev/null || true   # via inet-core

# ── Overlay tunnels ────────────────────────────────────────────────────────
ip tunnel add tun-mpls mode gre local 172.16.2.1 remote 172.16.1.1 ttl 64 2>/dev/null || true
ip link set tun-mpls up
ip addr add 10.255.1.2/30 dev tun-mpls 2>/dev/null || true

ip tunnel add tun-inet mode gre local 198.51.100.5 remote 198.51.100.1 ttl 64 2>/dev/null || true
ip link set tun-inet up
ip addr add 10.255.2.2/30 dev tun-inet 2>/dev/null || true

# ── Overlay routing ────────────────────────────────────────────────────────
ip route add 10.1.0.0/24 via 10.255.2.1 2>/dev/null || true

# ── App-aware policy: voice (DSCP EF) prefers the MPLS path ───────────────
nft add table ip sdwan
nft 'add chain ip sdwan classify { type filter hook prerouting priority mangle; }'
nft 'add rule ip sdwan classify ip dscp ef meta mark set 1'
ip rule add fwmark 1 table 100 pref 100 2>/dev/null || true
ip route add 10.1.0.0/24 via 10.255.1.1 table 100 2>/dev/null || true

# ── Path monitor ───────────────────────────────────────────────────────────
nohup sh /pathmon.sh > /var/log/pathmon.log 2>&1 &

echo "[branch2] Ready — LAN 10.2.0.0/24, tun-mpls 10.255.1.2, tun-inet 10.255.2.2"
