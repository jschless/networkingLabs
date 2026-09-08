#!/usr/bin/env bash
# Build the incidental shared WAN bridge deterministically.
set -euo pipefail

if ! ip link show br0 >/dev/null 2>&1; then
    ip link add name br0 type bridge
fi
ip link set dev br0 up

for port in eth1 eth2 eth3 eth4; do
    ip link set dev "$port" up
    ip link set dev "$port" master br0
done
