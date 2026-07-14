#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'interface Port-Channel1' 'switchport trunk allowed vlan 10,20' end; } | docker exec -i clab-troubleshooting-range-campus-acc1 Cli -p 15 >/dev/null
