#!/bin/sh
# mpls-core — the "MPLS provider" transport, reduced to one router.
#
#   eth1  172.16.1.2/30  (to branch1)
#   eth2  172.16.2.2/30  (to branch2)
#
# In real life this is a provider L3VPN with an SLA. Here it is one hop
# that forwards between the two branch WAN subnets — which is all the
# branches can see of a provider anyway.

ip link set eth1 up
ip addr add 172.16.1.2/30 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 172.16.2.2/30 dev eth2 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[mpls-core] Ready — forwarding 172.16.1.0/30 <-> 172.16.2.0/30"
