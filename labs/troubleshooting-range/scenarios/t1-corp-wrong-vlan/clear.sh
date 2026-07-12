#!/usr/bin/env bash
set -euo pipefail
{ printf '%s\n' enable configure 'interface Ethernet3' 'switchport access vlan 10' end; } | docker exec -i clab-troubleshooting-range-acc1 Cli -p 15 >/dev/null
