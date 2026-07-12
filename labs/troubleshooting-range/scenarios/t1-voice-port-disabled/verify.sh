#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-acc1 Cli -p 15 -c enable -c 'show interfaces Ethernet4 status' | grep -q connected
docker exec clab-troubleshooting-range-voice1 ping -c 2 -W 2 10.250.40.10 >/dev/null
echo 'PASS: voice access port and service reachability are restored.'
