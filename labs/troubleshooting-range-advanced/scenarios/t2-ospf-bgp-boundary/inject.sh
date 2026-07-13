#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" vtysh -c 'configure terminal' -c 'router ospf' -c 'no redistribute bgp metric 10 route-map INTERNET-ONLY' -c end
for _ in $(seq 1 15); do
  route="$(docker exec "$P-core1" vtysh -c 'show ip route 198.18.10.0/24' || true)"
  if [[ "$route" == *'10.251.0.3'* && "$route" != *'10.251.0.1'* ]]; then
    docker exec "$P-corp1" ping -c 1 -W 2 198.18.10.10 >/dev/null
    echo 'Ticket symptom is active.'; exit 0
  fi
  sleep 1
done
exit 1
