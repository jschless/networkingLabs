#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'no ip route 198.18.0.0/24 Null0' end; } | docker exec -i clab-troubleshooting-range-acc2 Cli -p 15 >/dev/null
