#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
{
    printf '%s\n' enable configure 'router ospf 1' 'no network 10.250.20.0/24 area 0.0.0.0' end
} | docker exec -i "$P-acc1" Cli -p 15 >/dev/null
for _ in $(seq 1 15); do
    if ! docker exec "$P-branch-client" ping -c 1 -W 1 10.250.20.10 >/dev/null 2>&1; then
        docker exec "$P-voice1" ping -c 1 -W 1 10.250.20.1 >/dev/null
        [[ "$(docker exec "$P-acc1" Cli -p 15 -c enable -c 'show ip ospf neighbor' | grep -ci full)" -ge 2 ]]
        echo 'Ticket symptom is active.'
        exit 0
    fi
    sleep 1
done
echo 'ERROR: remote voice-prefix symptom did not become active' >&2
exit 1
