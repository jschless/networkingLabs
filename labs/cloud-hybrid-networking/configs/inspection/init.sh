#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.60.100.10/30 dev eth1
ip addr add 10.60.100.13/30 dev eth2
ip addr add 10.60.100.17/30 dev eth3
ip addr add 10.63.10.1/24 dev eth4
for interface in eth1 eth2 eth3 eth4; do ip link set "$interface" up; done
