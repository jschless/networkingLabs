#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" vtysh -c 'show running-config' | grep -q 'redistribute bgp metric 10 route-map INTERNET-ONLY'
for _ in $(seq 1 20); do
  route="$(docker exec "$P-core1" vtysh -c 'show ip route 198.18.10.0/24' || true)"
  if [[ "$route" == *'10.251.0.1'* && "$route" == *'Known via "ospf"'* ]]; then
    docker exec "$P-corp1" ping -c 2 -W 2 198.18.10.10 >/dev/null
    echo 'PASS: the filtered primary route crosses the BGP/OSPF boundary.'; exit 0
  fi
  sleep 1
done
exit 1
