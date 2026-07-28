#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.114.50.10/24 dev eth1
ip link set eth1 up
ip route replace default via 10.114.50.1
