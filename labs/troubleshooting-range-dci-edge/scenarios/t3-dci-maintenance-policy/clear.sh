#!/usr/bin/env bash
set -euo pipefail
prefix=clab-troubleshooting-range-dci-edge
docker exec "$prefix-a-bgw" Cli -p 15 -c $'enable\nconfigure\nno route-map DCI-PROD deny 5\nend\nclear bgp * soft out' >/dev/null
