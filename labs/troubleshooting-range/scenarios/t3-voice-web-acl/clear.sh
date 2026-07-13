#!/usr/bin/env bash
set -euo pipefail
docker exec clab-troubleshooting-range-services1 iptables -D INPUT -p tcp -s 10.250.20.0/24 --dport 8080 -j DROP 2>/dev/null || true
