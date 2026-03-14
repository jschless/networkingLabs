#!/bin/bash
# CE1 setup: simple Linux host on L2VPN segment
# eth1 connects to pe1 attachment circuit — ce1 sees a plain Ethernet interface
set -e

ip link set eth1 up
ip addr add 10.100.0.1/24 dev eth1
