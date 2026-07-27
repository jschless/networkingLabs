#!/usr/bin/env bash
set -euo pipefail

P="clab-dc-storage-networking"
for spec in \
  "initiator1 eth1 eth2 br-a br-b tap-a tap-b" \
  "tor1 eth1 eth2 eth3 eth4 br-storage-a" \
  "tor2 eth1 eth2 eth3 br-storage-b" \
  "target1 eth1 eth2" \
  "target2 eth1 eth2" \
  "traffic-gen eth1"; do
  read -r node_name interfaces <<<"$spec"
  for iface in $interfaces; do
    docker exec "$P-$node_name" ip link set "$iface" mtu 9000
  done
done
docker exec "$P-initiator1" vm-exec sudo ip link set storagea mtu 9000
docker exec "$P-initiator1" vm-exec sudo ip link set storageb mtu 9000

# Re-establish each pre-existing TCP session so its negotiated MSS reflects the
# jumbo endpoint MTU. Drain one path at a time so the map retains service.
IQN="iqn.2026-07.lab.example:dc-storage"
for portal in 10.111.10.20:3260 10.111.20.20:3260; do
  docker exec "$P-initiator1" vm-exec sudo iscsiadm -m node -T "$IQN" \
    -p "$portal" --logout
  docker exec "$P-initiator1" vm-exec sudo iscsiadm -m node -T "$IQN" \
    -p "$portal" --login
done
docker exec "$P-initiator1" vm-exec sudo multipath -r >/dev/null
