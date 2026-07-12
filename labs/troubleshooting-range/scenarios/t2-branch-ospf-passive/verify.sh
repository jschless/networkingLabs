#!/usr/bin/env bash
set -euo pipefail
for _ in $(seq 1 15); do
  if docker exec clab-troubleshooting-range-branch1 vtysh -c 'show ip ospf neighbor' | grep -qi full \
    && docker exec clab-troubleshooting-range-branch-client ping -c 1 -W 1 10.250.40.10 >/dev/null; then
    echo 'PASS: branch OSPF adjacency and headquarters access are restored.'
    exit 0
  fi
  sleep 1
done
exit 1
