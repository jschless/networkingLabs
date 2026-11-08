#!/usr/bin/env bash
# hub — DC head-end: MPLS CE + Internet GRE head-end (AS65000).
set -euo pipefail
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip addr add 172.16.2.1/30 dev eth1
ip addr add 203.0.113.1/30 dev eth2
ip addr add 10.20.20.1/24 dev eth3
# Underlay: reach br2's public address over the Internet circuit only.
ip route add 198.51.100.1/32 via 203.0.113.2
# GRE overlay toward br2 (outer TTL 255 so eBGP's inner TTL=1 survives transit).
ip tunnel add tun0 mode gre local 203.0.113.1 remote 198.51.100.1 ttl 255
ip addr add 10.99.0.2/30 dev tun0
ip link set tun0 mtu 1476 up
