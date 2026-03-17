#!/bin/bash
set -e

# fw-outside baseline only: addressing, routing, forwarding.
# You build the nftables forward/NAT policy in the capstone.

ip link set eth1 up
ip addr add 203.0.114.2/30 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 172.16.0.1/30 dev eth2 2>/dev/null || true
ip link set eth3 up
ip addr add 172.16.0.5/30 dev eth3 2>/dev/null || true
ip link set eth4 up
ip addr add 172.16.1.1/30 dev eth4 2>/dev/null || true

ip route del default 2>/dev/null || true
ip route add default via 203.0.114.1 2>/dev/null || true
ip route add 203.0.113.0/30 via 203.0.114.1 2>/dev/null || true
ip route add 10.0.0.0/24 via 172.16.1.2 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

# Start with no policy so the learner builds both filter and NAT state.
nft flush ruleset

echo "[fw-outside] Baseline ready"
echo "  WAN:       203.0.114.2/30 (eth1)"
echo "  DMZ-web:   172.16.0.1/30  (eth2)"
echo "  DMZ-mail:  172.16.0.5/30  (eth3)"
echo "  DMZ-inner: 172.16.1.1/30  (eth4)"
echo "  Tasks:     publish DMZ services, allow outbound LAN access, log denies"
