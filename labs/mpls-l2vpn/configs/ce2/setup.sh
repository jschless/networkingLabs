#!/bin/bash
# CE2 setup: simple Linux host on L2VPN segment
# eth1 connects to pe2 attachment circuit — ce2 sees a plain Ethernet interface
set -e

ip link set eth1 up
ip addr add 10.100.0.2/24 dev eth1
