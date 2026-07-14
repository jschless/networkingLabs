#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
{ printf '%s\n' enable configure 'spanning-tree priority 0' end; } | docker exec -i "$P-acc1" Cli -p 15 >/dev/null
for _ in $(seq 1 15); do
    root="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show spanning-tree vlan 10' || true)"
    [[ "$root" == *'Priority    0'* && "$root" == *'This bridge is the root'* ]] && break
    sleep 1
done
[[ "$root" == *'Priority    0'* && "$root" == *'This bridge is the root'* ]]
docker exec "$P-campus1" ping -c 2 -W 1 10.252.20.10 >/dev/null
echo 'Ticket symptom is active.'
