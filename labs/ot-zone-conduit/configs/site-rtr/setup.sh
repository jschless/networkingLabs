#!/usr/bin/env bash
set -euo pipefail
install -d /run/ot
ip addr replace 10.110.30.2/24 dev eth1
ip addr replace 10.110.40.1/24 dev eth2
ip link set eth1 up
ip link set eth2 up
ip route replace default via 10.110.30.1
sysctl -q -w net.ipv4.ip_forward=1
nft flush ruleset
