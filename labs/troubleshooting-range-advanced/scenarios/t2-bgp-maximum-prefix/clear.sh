#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced
docker exec "$P-internet-core" /usr/lib/frr/frr-reload.py --reload /opt/range/golden/frr.conf --overwrite >/dev/null
docker exec "$P-edge1" /usr/lib/frr/frr-reload.py --reload /opt/range/golden/frr.conf --overwrite >/dev/null
