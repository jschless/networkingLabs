#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-guest1 ip route replace default via 10.250.30.1
