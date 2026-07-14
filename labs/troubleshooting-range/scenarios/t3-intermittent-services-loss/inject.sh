#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range

docker exec "$P-core1" tc qdisc replace dev eth5 root netem loss 35%
docker exec "$P-core1" tc qdisc show dev eth5 | grep -q 'netem.*loss 35%'
[[ "$(docker exec "$P-core1" vtysh -c 'show ip ospf neighbor' | grep -ci Full)" -ge 4 ]]
docker exec "$P-services1" pgrep -f 'python3 -m http.server 8080' >/dev/null

sample="$(docker exec "$P-corp1" ping -c 20 -W 1 10.250.40.10 2>&1 || true)"
received="$(printf '%s\n' "$sample" | awk '/packets transmitted/ {print $4}')"
[[ "${received:-0}" -gt 0 && "${received:-20}" -lt 20 ]]
echo 'Ticket symptom is active.'
