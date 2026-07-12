#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-guest1" ip route replace default via 10.250.30.254
! docker exec "$P-guest1" ping -c 1 -W 1 198.18.0.10 >/dev/null 2>&1
echo 'Ticket symptom is active.'
