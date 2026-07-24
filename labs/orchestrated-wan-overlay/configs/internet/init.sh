#!/usr/bin/env bash
set -euo pipefail
ip addr add 192.0.2.113/30 dev eth1; ip addr add 192.0.2.117/30 dev eth2; ip addr add 192.0.2.121/30 dev eth3; ip addr add 10.113.50.1/24 dev eth4
for i in eth1 eth2 eth3 eth4; do ip link set "$i" up; done
ip route replace 10.113.10.0/24 via 192.0.2.112
ip route replace 10.113.110.0/24 via 192.0.2.112
ip route replace 10.113.20.0/24 via 192.0.2.120
ip route replace 10.113.120.0/24 via 192.0.2.120
