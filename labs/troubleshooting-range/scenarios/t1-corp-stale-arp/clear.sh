#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-corp1 ip neigh del 10.250.10.1 dev eth1 2>/dev/null || true
