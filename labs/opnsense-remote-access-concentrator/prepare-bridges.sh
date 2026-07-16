#!/usr/bin/env bash
set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
for bridge in br-remote-wan br-corp; do
    ip link show "$bridge" >/dev/null 2>&1 || ip link add name "$bridge" type bridge
    ip link set "$bridge" up
done
