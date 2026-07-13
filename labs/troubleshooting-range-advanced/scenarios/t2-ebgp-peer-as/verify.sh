#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
for _ in $(seq 1 30); do
  out="$(docker exec "$P-edge2" vtysh -c 'show bgp neighbor 192.0.2.3' || true)"
  if [[ "$out" == *'BGP state = Established'* && "$out" == *'remote AS 64502'* ]]; then
    docker exec "$P-edge2" vtysh -c 'show bgp ipv4 unicast 198.18.10.0/24' | grep -q '192.0.2.3'
    docker exec "$P-branch-client" ping -c 1 -W 2 198.18.10.10 >/dev/null
    echo 'PASS: the backup provider peer is Established and advertising the service prefix.'; exit 0
  fi
  sleep 1
done
exit 1
