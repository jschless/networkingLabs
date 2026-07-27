#!/usr/bin/env bash
set -euo pipefail

docker exec clab-dc-storage-networking-tor1 ip link set eth2 mtu 1500
echo "Injected: tor1 eth2 is 1500 while the Storage A endpoints remain 9000."
