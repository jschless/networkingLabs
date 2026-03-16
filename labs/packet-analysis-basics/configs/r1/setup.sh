#!/bin/bash
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up

# FRR is already started by the container entrypoint; apply interface config after links exist.
vtysh -b

# Mirror routed transit traffic to the analyzer.
tc qdisc add dev eth2 clsact
tc filter add dev eth2 ingress matchall action mirred egress mirror dev eth3
tc filter add dev eth2 egress matchall action mirred egress mirror dev eth3

echo "[r1] OSPF active, eth2 mirrored to eth3 for analyzer capture"
