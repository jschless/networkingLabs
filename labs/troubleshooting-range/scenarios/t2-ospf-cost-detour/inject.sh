#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
{
    printf '%s\n' enable configure 'interface Ethernet1' 'ip ospf cost 100' end
} | docker exec -i "$P-acc1" Cli -p 15 >/dev/null
for _ in $(seq 1 15); do
    route="$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show ip route 10.250.40.10')"
    if [[ "$route" == *'via 10.250.0.2, Ethernet2'* ]]; then
        docker exec "$P-corp1" ping -c 1 -W 1 10.250.40.10 >/dev/null
        echo 'Ticket symptom is active.'
        exit 0
    fi
    sleep 1
done
echo 'ERROR: services path did not move to the redundant uplink' >&2
exit 1
