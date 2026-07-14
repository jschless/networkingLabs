#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
for _ in $(seq 1 20); do
    root="$(docker exec "$P-dist1" Cli -p 15 -c enable -c 'show spanning-tree vlan 10' || true)"
    [[ "$root" == *'This bridge is the root'* && "$root" == *'Priority    4096'* ]] && break
    sleep 1
done
[[ "$root" == *'This bridge is the root'* && "$root" == *'Priority    4096'* ]]
access_root="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show spanning-tree root')"
[[ "$access_root" == *'4096'* ]]
docker exec "$P-campus1" ping -c 3 -W 1 10.252.20.10 >/dev/null
echo 'PASS: the distribution switch is again the intended root and user forwarding remains healthy.'
