#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.60.100.6/30 dev eth1
ip addr add 10.60.100.18/30 dev eth2
ip addr add 10.62.10.10/32 dev lo
for interface in eth1 eth2 lo; do ip link set "$interface" up; done
