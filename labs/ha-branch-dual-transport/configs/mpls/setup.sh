#!/usr/bin/env bash
# mpls — the carrier's PE, collapsed into one box (AS65100).
set -euo pipefail
ip link set eth1 up
ip link set eth2 up
ip addr add 172.16.1.2/30 dev eth1
ip addr add 172.16.2.2/30 dev eth2
