#!/usr/bin/env bash
set -euo pipefail
ip link set dev eth1 up
ip -4 address flush dev eth1 scope global
ip -4 route flush dev eth1
ip -4 address flush dev lo scope global
ip -4 route flush default
ip address add 10.20.34.2/30 dev eth1
ip address add 10.20.0.2/32 dev lo
ip route add default via 10.20.34.1 dev eth1
