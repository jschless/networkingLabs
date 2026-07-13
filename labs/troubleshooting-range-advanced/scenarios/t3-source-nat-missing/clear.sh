#!/usr/bin/env bash
set -euo pipefail
P=clab-troubleshooting-range-advanced-edge1
docker exec "$P" iptables -t nat -C POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE 2>/dev/null || docker exec "$P" iptables -t nat -A POSTROUTING -s 10.251.0.0/16 -o eth3 -j MASQUERADE
