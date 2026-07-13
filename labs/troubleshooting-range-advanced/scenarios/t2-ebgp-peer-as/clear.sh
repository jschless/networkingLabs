#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-advanced-edge2 /usr/lib/frr/frr-reload.py --reload /opt/range/golden/frr.conf --overwrite >/dev/null
