#!/usr/bin/env bash
set -euo pipefail
ip addr add 169.254.60.2/30 dev eth1
ip addr add 169.254.60.6/30 dev eth2
ip addr add 10.60.100.1/30 dev eth3
ip addr add 10.60.100.5/30 dev eth4
ip addr add 10.60.100.9/30 dev eth5
ip addr add 198.18.60.1/30 dev eth6
for interface in eth1 eth2 eth3 eth4 eth5 eth6; do ip link set "$interface" up; done
