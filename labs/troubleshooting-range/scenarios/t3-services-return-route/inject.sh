#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-services1" ip route replace default via 10.250.40.254
output="$(docker exec "$P-corp1" sh -lc 'timeout 2 nslookup web.range.test 10.250.40.10' 2>/dev/null || true)"
[[ "$output" != *'Name:'*'web.range.test'* ]]
docker exec "$P-corp1" ping -c 1 -W 1 10.250.50.10 >/dev/null
echo 'Ticket symptom is active.'
