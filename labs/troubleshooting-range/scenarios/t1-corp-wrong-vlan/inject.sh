#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'interface Ethernet3' 'switchport access vlan 20' end; } | docker exec -i clab-troubleshooting-range-acc1 Cli -p 15 >/dev/null
! docker exec clab-troubleshooting-range-corp1 ping -c 1 -W 1 10.250.50.10 >/dev/null 2>&1
echo 'Ticket symptom is active.'
