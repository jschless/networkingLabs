#!/usr/bin/env bash
set -euo pipefail
ip addr add 203.0.113.10/24 dev eth1
ip route replace default via 203.0.113.2
ip link set eth1 up
