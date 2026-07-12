#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-edge vtysh -c 'configure terminal' -c 'interface eth1' -c shutdown -c end
for _ in $(seq 1 10); do
  if ! docker exec clab-troubleshooting-range-core1 vtysh -c 'show ip ospf neighbor' | grep -q '10.250.255.31'; then echo 'Ticket symptom is active.'; exit 0; fi
  sleep 1
done
exit 1
