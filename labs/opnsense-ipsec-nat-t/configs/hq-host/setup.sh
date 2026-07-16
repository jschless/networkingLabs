#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.10.1.10/24 dev eth1
ip route replace default via 10.10.1.1
ip link set eth1 up
