#!/usr/bin/env bash
set -euo pipefail
{
    printf '%s\n' enable configure 'router ospf 1' 'network 10.250.20.0/24 area 0.0.0.0' end
} | docker exec -i clab-troubleshooting-range-acc1 Cli -p 15 >/dev/null
