#!/bin/sh
set -eu

ip link add br-wan type bridge 2>/dev/null || true
ip link set br-wan up

for port in eth1 eth2 eth3; do
    ip address flush dev "$port"
    ip link set "$port" up
    ip link set "$port" master br-wan
done

echo "WAN segment ready"
