#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-dci-edge
docker exec "$prefix-carrier-nid-b" bash /opt/range/golden/reset.sh
