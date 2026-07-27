#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.109.30.53/24 dev eth1
ip route replace default via 10.109.30.1 dev eth1
mkdir -p /run/voice /var/lib/misc
# DHCP, DNS, and NTP policy are intentionally withheld for Task 2.
printf 'WITHHELD\n' >/run/voice/services-state
