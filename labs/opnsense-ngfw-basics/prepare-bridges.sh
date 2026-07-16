#!/usr/bin/env bash
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
    echo "Run as root to create host bridges." >&2
    exit 1
fi

for bridge in br-ngfw-wan br-ngfw-corp br-ngfw-guest br-ngfw-dmz br-ngfw-db; do
    if ! ip link show "$bridge" >/dev/null 2>&1; then
        ip link add name "$bridge" type bridge
    fi
    ip link set "$bridge" up
done

echo "OPNsense host bridges are ready."
