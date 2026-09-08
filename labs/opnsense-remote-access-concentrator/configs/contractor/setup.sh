#!/usr/bin/env bash
set -euo pipefail

# The deploy baseline is intentionally answer-free. Learners create wg0 and
# its per-deployment identity after proving the public underlay.
ip link delete wg0 >/dev/null 2>&1 || true
rm -rf /run/opnsense-ra-lab
ip addr replace 203.0.113.20/24 dev eth1
ip route replace default via 203.0.113.2
ip link set eth1 up
