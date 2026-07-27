#!/usr/bin/env bash
set -euxo pipefail

ip link add br-mgmt type bridge
for iface in eth1 eth2 eth3; do
  ip link set "$iface" master br-mgmt
  ip link set "$iface" up
done
ip link set br-mgmt up
ip addr add 10.111.30.40/24 dev br-mgmt
mkdir -p /captures
printf 'READY\n' >/run/storage-observer-ready
