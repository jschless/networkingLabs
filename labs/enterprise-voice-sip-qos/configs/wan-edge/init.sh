#!/usr/bin/env bash
set -euo pipefail
ip addr add 192.0.2.110/30 dev eth1
ip addr add 198.51.100.109/30 dev eth2
ip route replace 10.109.0.0/16 via 192.0.2.109 dev eth1
ip route replace 10.109.40.0/24 via 198.51.100.110 dev eth2
sysctl -qw net.ipv4.ip_forward=1
mkdir -p /run/voice
printf 'WITHHELD\n' >/run/voice/edge-state
