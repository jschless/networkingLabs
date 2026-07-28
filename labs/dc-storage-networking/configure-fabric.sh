#!/usr/bin/env bash
set -euo pipefail

P="clab-dc-storage-networking"

docker exec "$P-tor1" bash -c '
  ip link show br-storage-a >/dev/null 2>&1 || ip link add br-storage-a type bridge
  for i in eth1 eth2 eth3 eth4; do ip link set "$i" master br-storage-a; ip link set "$i" up; done
  ip link set br-storage-a mtu 1500
  ip link set br-storage-a up
'

docker exec "$P-tor2" bash -c '
  ip link show br-storage-b >/dev/null 2>&1 || ip link add br-storage-b type bridge
  for i in eth1 eth2 eth3; do ip link set "$i" master br-storage-b; ip link set "$i" up; done
  ip link set br-storage-b mtu 1500
  ip link set br-storage-b up
'
