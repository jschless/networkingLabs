#!/usr/bin/env bash
set -euo pipefail
install -d /run/ot
ip addr replace 10.110.11.2/30 dev eth1
ip link add br-idmz type bridge 2>/dev/null || true
ip link set eth2 master br-idmz
ip link set eth3 master br-idmz
ip link set eth2 up
ip link set eth3 up
ip addr replace 10.110.20.1/24 dev br-idmz
ip link set br-idmz up
ip addr replace 10.110.30.1/24 dev eth4
ip link set eth1 up
ip link set eth4 up
ip route replace 10.110.10.0/24 via 10.110.11.1
ip route replace 10.110.40.0/24 via 10.110.30.2
sysctl -q -w net.ipv4.ip_forward=1
nft flush ruleset
