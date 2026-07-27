#!/usr/bin/env bash
set -euo pipefail

docker exec clab-dc-storage-networking-tor1 ip link set eth2 mtu 9000
echo "Repaired: tor1 eth2 restored to MTU 9000."
