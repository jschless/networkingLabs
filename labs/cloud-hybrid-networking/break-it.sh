#!/usr/bin/env bash
# Deliberately associate App A's return domain with the direct transit table.
set -euo pipefail
docker exec clab-cloud-hybrid-networking-app-a-rtr bash -c \
  'ip route replace table 101 10.60.10.0/24 via 10.60.100.1'
echo 'Break-It injected: App A return traffic now bypasses inspection.'
