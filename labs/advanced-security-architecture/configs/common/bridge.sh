#!/usr/bin/env bash
set -euo pipefail
ip link add br0 type bridge
ip link set br0 up
for port in $PORTS; do
    ip link set "$port" master br0
    ip link set "$port" up
done
