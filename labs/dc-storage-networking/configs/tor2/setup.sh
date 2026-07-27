#!/usr/bin/env bash
set -euxo pipefail

for iface in eth1 eth2 eth3; do
  ip link set "$iface" mtu 1500
  ip link set "$iface" up
done
