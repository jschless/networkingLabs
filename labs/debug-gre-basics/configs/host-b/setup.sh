#!/usr/bin/env bash
set -euo pipefail

ip link set dev eth1 up
ip -4 addr flush dev eth1
ip addr add 192.168.2.10/24 dev eth1
ip route replace default via 192.168.2.1 dev eth1
