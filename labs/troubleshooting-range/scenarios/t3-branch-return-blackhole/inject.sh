#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-core1 vtysh -c 'configure terminal' -c 'ip route 10.250.50.0/24 Null0' -c end
! docker exec clab-troubleshooting-range-branch-client ping -c 1 -W 1 10.250.40.10 >/dev/null 2>&1
docker exec clab-troubleshooting-range-branch-client ping -c 1 -W 1 10.250.10.10 >/dev/null
echo 'Ticket symptom is active.'
