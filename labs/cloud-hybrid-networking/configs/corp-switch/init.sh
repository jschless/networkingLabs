#!/usr/bin/env bash
set -euo pipefail
ip link add br0 type bridge
for interface in eth1 eth2 eth3; do
  ip link set "$interface" master br0
  ip link set "$interface" up
done
ip link set br0 up
