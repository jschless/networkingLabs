#!/bin/bash
# edge2 — second router between OUTSIDE and the DMZ
#
# eth1: 203.0.113.3/29 (OUTSIDE)
# eth2: 172.16.0.2/24  (DMZ)
#
# Carries no traffic in the lab's normal state. It exists so that a DMZ
# host *can* route out a different door than it came in — which is the
# whole point of one of the later exercises.

ip link set eth1 up
ip addr add 203.0.113.3/29 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 172.16.0.2/24 dev eth2 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[edge2] Ready — 203.0.113.3/29 <-> 172.16.0.2/24, forwarding on"
