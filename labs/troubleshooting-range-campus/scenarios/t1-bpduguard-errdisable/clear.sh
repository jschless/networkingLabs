#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'interface Ethernet5' shutdown 'no shutdown' end; } | docker exec -i clab-troubleshooting-range-campus-acc1 Cli -p 15 >/dev/null
