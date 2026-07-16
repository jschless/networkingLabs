#!/usr/bin/env bash
set -euo pipefail
[[ "$(id -u)" -eq 0 ]] || { echo "Run with sudo." >&2; exit 1; }
for bridge in br-corp br-remote-wan; do
    ip link show "$bridge" >/dev/null 2>&1 || continue
    ip link set "$bridge" down || true
    ip link del "$bridge" type bridge || true
done
