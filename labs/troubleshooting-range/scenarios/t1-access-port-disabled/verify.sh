#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-acc1" Cli -p 15 -c enable -c 'show interfaces Ethernet3 status' | grep -q connected
docker exec "$P-corp1" ping -c 2 -W 2 10.250.50.10 >/dev/null
echo "PASS: access port and corporate reachability are restored."
