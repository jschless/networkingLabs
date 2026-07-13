#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-core1 ip link set eth3 mtu 1500
