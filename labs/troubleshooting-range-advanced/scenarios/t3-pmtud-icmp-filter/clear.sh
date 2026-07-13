#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-advanced-edge1 iptables -D OUTPUT -p icmp --icmp-type fragmentation-needed -j DROP 2>/dev/null || true
docker exec clab-troubleshooting-range-advanced-internet1 ip route flush cache || true
