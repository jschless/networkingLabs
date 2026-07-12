#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'no ip route 10.250.50.0/24 Null0' end; } | docker exec -i clab-troubleshooting-range-acc1 Cli -p 15 >/dev/null
