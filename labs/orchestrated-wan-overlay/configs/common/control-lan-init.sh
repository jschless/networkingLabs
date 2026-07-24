#!/usr/bin/env bash
set -euo pipefail
ip link add br0 type bridge
for i in eth1 eth2 eth3 eth4 eth5; do ip link set "$i" master br0; ip link set "$i" up; done
ip link set br0 up
