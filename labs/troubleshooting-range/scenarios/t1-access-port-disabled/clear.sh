#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
{
    printf '%s\n' enable configure 'interface Ethernet3' 'no shutdown' end
} | docker exec -i "$P-acc1" Cli -p 15 >/dev/null
