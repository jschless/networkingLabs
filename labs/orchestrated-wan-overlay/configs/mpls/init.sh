#!/usr/bin/env bash
set -euo pipefail
ip addr add 172.20.113.2/30 dev eth1; ip addr add 172.20.113.6/30 dev eth2; ip addr add 172.20.113.10/30 dev eth3
for i in eth1 eth2 eth3; do ip link set "$i" up; done
