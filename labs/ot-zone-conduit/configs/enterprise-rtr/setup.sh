#!/usr/bin/env bash
set -euo pipefail
ip addr replace 10.110.10.1/24 dev eth1
ip addr replace 10.110.11.1/30 dev eth2
ip link set eth1 up
ip link set eth2 up
ip route replace 10.110.20.0/24 via 10.110.11.2
ip route replace 10.110.30.0/24 via 10.110.11.2
ip route replace 10.110.40.0/24 via 10.110.11.2
sysctl -q -w net.ipv4.ip_forward=1
