#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-core2 vtysh -c 'configure terminal' -c 'interface eth5' -c 'no shutdown' -c 'no ip ospf passive' -c end
