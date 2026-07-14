#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
{ printf '%s\n' enable configure 'interface Ethernet2' 'no channel-group 1' end; } | docker exec -i "$P-acc1" Cli -p 15 >/dev/null
for _ in $(seq 1 15); do
    peers="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show lacp peer' || true)"
    [[ "$peers" == *'Et1'*Bundled* && "$peers" != *'Et2'*Bundled* ]] && break
    sleep 1
done
[[ "$peers" == *'Et1'*Bundled* && "$peers" != *'Et2'*Bundled* ]]
docker exec "$P-campus1" ping -c 2 -W 1 10.252.20.10 >/dev/null
echo 'Ticket symptom is active.'
