#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-core1 vtysh -c 'configure terminal' -c 'no ip route 10.250.10.0/24 Null0' -c end
