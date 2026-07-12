#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-acc1 Cli -p 15 -c enable -c 'show interfaces Ethernet3 switchport' | grep -q 'Access Mode VLAN: 10'
docker exec clab-troubleshooting-range-corp1 ping -c 2 -W 2 10.250.50.10 >/dev/null
echo 'PASS: corporate access VLAN and reachability are restored.'
