#!/usr/bin/env bash
set -euo pipefail
ip link set dev eth1 up
ip -4 address flush dev eth1 scope global
ip -4 route flush dev eth1
ip -4 address flush dev lo scope global
ip -4 route flush default
ip address add 10.10.12.1/30 dev eth1
ip address add 10.10.0.1/32 dev lo
ip route add default via 10.10.12.2 dev eth1
