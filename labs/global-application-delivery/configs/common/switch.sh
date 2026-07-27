#!/bin/sh
set -eu
ip link add br0 type bridge 2>/dev/null || true
ip link set br0 up
for iface in /sys/class/net/eth*; do
    iface="${iface##*/}"
    [ "$iface" = eth0 ] && continue
    ip addr flush dev "$iface" 2>/dev/null || true
    ip link set "$iface" master br0
    ip link set "$iface" up
done
