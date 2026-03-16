#!/bin/bash
set -e
ip link add br0 type bridge
ip link set br0 up
for iface in eth1 eth2 eth3; do
  ip link set "$iface" up
  ip link set "$iface" master br0
done
echo "[sw1] Linux bridge ready"
