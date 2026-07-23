#!/usr/bin/env bash
set -euo pipefail
ip link set eth1 up
ip addr add 10.120.0.10/24 dev eth1
echo "Guest endpoint: VLAN 120 policy fixture; no live WLAN association is claimed." >/etc/motd
