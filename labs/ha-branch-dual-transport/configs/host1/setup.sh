#!/usr/bin/env bash
# host1 — branch user. LACP bond across acc1/acc2; gateway is the VRRP VIP.
set -euo pipefail
ip link add bond0 type bond mode 802.3ad miimon 100 lacp_rate fast xmit_hash_policy layer3+4
ip link set eth1 down
ip link set eth2 down
ip link set eth1 master bond0
ip link set eth2 master bond0
ip link set eth1 up
ip link set eth2 up
ip link set bond0 up
ip addr add 10.10.10.100/24 dev bond0
ip route del default 2>/dev/null || true
ip route add default via 10.10.10.1
