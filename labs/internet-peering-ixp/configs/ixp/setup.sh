#!/usr/bin/env bash
set -euo pipefail
for interface in eth1 eth2 eth3 eth4 eth5 eth6; do
  for _ in $(seq 1 30); do ip link show "$interface" >/dev/null 2>&1 && break; sleep 1; done
done
ip link add br0 type bridge 2>/dev/null || true
ip link set br0 up
for interface in eth1 eth2 eth3 eth4 eth5 eth6; do
  ip link set "$interface" master br0
  ip link set "$interface" up
done
