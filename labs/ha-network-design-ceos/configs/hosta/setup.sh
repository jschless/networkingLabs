#!/usr/bin/env bash
set -euo pipefail

ip link add bond0 type bond mode 802.3ad miimon 100 lacp_rate fast
ip link set bond0 up

ip link set eth1 down
ip link set eth2 down
ip link set eth1 master bond0
ip link set eth2 master bond0
ip link set eth1 up
ip link set eth2 up

ip addr add 192.168.10.10/24 dev bond0
ip route del default || true
ip route add default via 192.168.10.254
