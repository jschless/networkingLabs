#!/usr/bin/env bash
set -euo pipefail
{
    printf '%s\n' enable configure 'interface Ethernet1' 'no ip ospf cost' end
} | docker exec -i clab-troubleshooting-range-acc1 Cli -p 15 >/dev/null
