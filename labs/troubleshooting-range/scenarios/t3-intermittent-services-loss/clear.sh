#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-core1 tc qdisc del dev eth5 root 2>/dev/null || true
