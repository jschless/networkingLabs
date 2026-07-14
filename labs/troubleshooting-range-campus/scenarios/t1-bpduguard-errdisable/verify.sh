#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
status="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show interfaces status')"
[[ "$status" == *'Et5'*connected* && "$status" != *'Et5'*errdisabled* ]]
running="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show running-config interfaces Ethernet5')"
grep -q 'spanning-tree bpduguard enable' <<<"$running"
docker exec "$P-campus1" ping -c 2 -W 1 10.252.10.1 >/dev/null
echo 'PASS: the protected edge was safely recovered and BPDU protection remains configured.'
