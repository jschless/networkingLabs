#!/usr/bin/env bash
set -euo pipefail
ip link add br-cell type bridge 2>/dev/null || true
for iface in eth1 eth2 eth3 eth4 eth5 eth6; do
  ip link set "$iface" master br-cell
  ip link set "$iface" up
done
ip link set eth7 up
ip link set br-cell up
for iface in eth1 eth2 eth3 eth4 eth5 eth6; do
  tc qdisc replace dev "$iface" clsact
  tc filter replace dev "$iface" ingress matchall \
    action mirred egress mirror dev eth7
done
