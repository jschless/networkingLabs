#!/usr/bin/env bash
set -euo pipefail
ip addr add 198.51.100.110/30 dev eth1
ip addr add 10.109.40.1/24 dev eth2
ip route replace default via 198.51.100.109 dev eth1
sysctl -qw net.ipv4.ip_forward=1
mkdir -p /run/voice
# This is an SBC-like routed demarcation, not a commercial B2BUA.
printf 'ROUTED_DEMARC\n' >/run/voice/sbc-role
