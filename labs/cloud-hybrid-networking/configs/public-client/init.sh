#!/usr/bin/env bash
set -euo pipefail
ip addr add 198.18.60.2/30 dev eth1
ip link set eth1 up
ip route replace default via 198.18.60.1
