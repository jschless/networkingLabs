#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
trunk="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show interfaces trunk')"
[[ "$trunk" == *'10,20'* ]]
docker exec "$P-campus1" ping -c 3 -W 1 10.252.10.1 >/dev/null
docker exec "$P-voice1" ping -c 3 -W 1 10.252.20.1 >/dev/null
docker exec "$P-campus1" ping -c 3 -W 1 10.252.20.10 >/dev/null
echo 'PASS: both user VLANs are carried across the campus trunk and routed service is healthy.'
