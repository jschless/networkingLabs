#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'ip route 10.250.50.0/24 Null0' end; } | docker exec -i clab-troubleshooting-range-acc1 Cli -p 15 >/dev/null
! docker exec clab-troubleshooting-range-corp1 ping -c 1 -W 1 10.250.50.10 >/dev/null 2>&1
docker exec clab-troubleshooting-range-corp1 ping -c 1 -W 1 10.250.40.10 >/dev/null
echo 'Ticket symptom is active.'
