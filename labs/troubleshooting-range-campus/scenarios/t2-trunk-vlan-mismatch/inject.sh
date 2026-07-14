#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-campus
{ printf '%s\n' enable configure 'interface Port-Channel1' 'switchport trunk allowed vlan 10' end; } | docker exec -i "$P-acc1" Cli -p 15 >/dev/null
docker exec "$P-campus1" ping -c 2 -W 1 10.252.10.1 >/dev/null
if docker exec "$P-voice1" ping -c 2 -W 1 10.252.20.1 >/dev/null 2>&1; then
    echo 'ERROR: voice VLAN symptom did not become active' >&2
    exit 1
fi
echo 'Ticket symptom is active.'
