#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-edge vtysh -c 'configure terminal' -c 'interface eth1' -c 'no shutdown' -c 'no ip ospf passive' -c end
