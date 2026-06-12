#!/bin/sh
# inet-core — the "internet" transport, reduced to one router.
#
#   eth1  198.51.100.2/30  (to branch1)
#   eth2  198.51.100.6/30  (to branch2)
#
# No SLA, no promises — the README's demos degrade this path's rival
# (mpls-core) and this one carries the failover traffic.

ip link set eth1 up
ip addr add 198.51.100.2/30 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 198.51.100.6/30 dev eth2 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[inet-core] Ready — forwarding 198.51.100.0/30 <-> 198.51.100.4/30"
