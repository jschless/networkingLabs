#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-corp1" pkill -f range_accept_client 2>/dev/null || true
docker exec "$P-services1" pkill -f range_accept_stall 2>/dev/null || true
docker exec "$P-services1" sh /opt/range/golden/reset.sh
