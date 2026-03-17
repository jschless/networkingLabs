#!/bin/bash
set -e

# fw-inside baseline only: addressing, routing, forwarding.
# You build the nftables policy separating DMZ and LAN in the capstone.

ip link set eth1 up
ip addr add 172.16.1.2/30 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 10.0.0.1/30 dev eth2 2>/dev/null || true
ip link set eth3 up
ip addr add 10.0.0.5/30 dev eth3 2>/dev/null || true

ip route del default 2>/dev/null || true
ip route add default via 172.16.1.1 2>/dev/null || true
ip route add 172.16.0.0/30 via 172.16.1.1 2>/dev/null || true
ip route add 172.16.0.4/30 via 172.16.1.1 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

nft flush ruleset

echo "[fw-inside] Baseline ready"
echo "  DMZ-inner: 172.16.1.2/30 (eth1)"
echo "  LAN-db:    10.0.0.1/30   (eth2)"
echo "  LAN-ws:    10.0.0.5/30   (eth3)"
echo "  Tasks:     allow workstation management and app-to-db only, log denies"
