#!/usr/bin/env bash
set -euo pipefail
for _ in $(seq 1 60); do
  if docker exec clab-troubleshooting-range-core1 vtysh -c 'show ip ospf neighbor' | grep -q '10.250.255.31.*Full'; then echo 'PASS: core1/edge OSPF adjacency is restored.'; exit 0; fi
  sleep 1
done
exit 1
