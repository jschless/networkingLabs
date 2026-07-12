#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-core1 vtysh -c 'configure terminal' -c 'ip route 10.250.10.0/24 Null0' -c end
output="$(docker exec clab-troubleshooting-range-corp1 sh -lc 'timeout 2 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
[[ "$output" != *'Name:'*'web.range.test'* ]]
docker exec clab-troubleshooting-range-corp1 ping -c 1 -W 1 10.250.50.10 >/dev/null
echo 'Ticket symptom is active.'
