#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root to remove host bridges." >&2
    exit 1
fi

for bridge in br-fgt-db br-fgt-dmz br-fgt-guest br-fgt-corp br-fgt-wan; do
    if ip link show "$bridge" >/dev/null 2>&1; then
        ip link set "$bridge" down || true
        ip link del "$bridge" type bridge || true
    fi
done

echo "FortiGate host bridges removed."
