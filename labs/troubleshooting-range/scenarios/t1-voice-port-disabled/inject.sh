#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'interface Ethernet4' shutdown end; } | docker exec -i clab-troubleshooting-range-acc1 Cli -p 15 >/dev/null
! docker exec clab-troubleshooting-range-voice1 ping -c 1 -W 1 10.250.40.10 >/dev/null 2>&1
echo 'Ticket symptom is active.'
