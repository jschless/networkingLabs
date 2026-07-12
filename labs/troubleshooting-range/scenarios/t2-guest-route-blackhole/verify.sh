#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-guest1 ping -c 2 -W 2 198.18.0.10 >/dev/null
echo 'PASS: guest external route is restored.'
