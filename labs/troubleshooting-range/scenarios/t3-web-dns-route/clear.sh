#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range
docker exec "$P-core1" vtysh -c 'configure terminal' -c 'interface eth5' -c 'no shutdown' -c end
