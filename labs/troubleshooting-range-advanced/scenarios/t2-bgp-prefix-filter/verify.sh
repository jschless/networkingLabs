#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
! docker exec "$P-edge1" vtysh -c 'show running-config' | grep -q 'BLOCK-IN'
for _ in $(seq 1 20); do
  route="$(docker exec "$P-edge1" vtysh -c 'show bgp ipv4 unicast 198.18.10.0/24' || true)"
  if [[ "$route" == *'192.0.2.1'* && "$route" == *'localpref 200'* ]]; then
    docker exec "$P-corp1" ping -c 2 -W 2 198.18.10.10 >/dev/null
    echo 'PASS: ISP1 supplies the preferred service prefix and client traffic succeeds.'; exit 0
  fi
  sleep 1
done
exit 1
