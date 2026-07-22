#!/usr/bin/env bash
set -euo pipefail
docker exec clab-cloud-hybrid-networking-app-a-rtr bash -c \
  'ip route replace table 101 10.60.10.0/24 via 10.60.100.13'
echo 'Repair applied: App A return traffic is associated with inspection-return.'
