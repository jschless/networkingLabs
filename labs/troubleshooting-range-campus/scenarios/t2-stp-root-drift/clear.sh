#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'spanning-tree priority 32768' end; } | docker exec -i clab-troubleshooting-range-campus-acc1 Cli -p 15 >/dev/null
