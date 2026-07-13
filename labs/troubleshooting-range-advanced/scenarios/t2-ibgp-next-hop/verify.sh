#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-edge1" vtysh -c 'show running-config' | grep -q 'neighbor 10.251.0.5 next-hop-self'
for _ in $(seq 1 20); do
  route="$(docker exec "$P-edge2" vtysh -c 'show bgp ipv4 unicast 198.18.10.0/24' || true)"
  if [[ "$route" == *'10.251.0.4'* && "$route" == *'localpref 200'* ]]; then
    docker exec "$P-branch-client" ping -c 1 -W 2 198.18.10.10 >/dev/null
    echo 'PASS: edge2 installs the preferred resolvable iBGP path.'; exit 0
  fi
  sleep 1
done
exit 1
