#!/usr/bin/env bash
set -euo pipefail

ip link set eth1 up
ip link set eth2 up

ip addr add 203.255.1.1/32 dev lo
ip addr add 203.0.113.1/31 dev eth1
ip addr add 198.51.100.0/31 dev eth2

ip route add 172.20.20.20/32 via 198.51.100.1
