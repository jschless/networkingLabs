#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'ip route 198.18.0.0/24 Null0' end; } | docker exec -i clab-troubleshooting-range-acc2 Cli -p 15 >/dev/null
! docker exec clab-troubleshooting-range-guest1 ping -c 1 -W 1 198.18.0.10 >/dev/null 2>&1
docker exec clab-troubleshooting-range-guest1 ping -c 1 -W 1 10.250.40.10 >/dev/null
echo 'Ticket symptom is active.'
