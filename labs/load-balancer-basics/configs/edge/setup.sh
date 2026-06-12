#!/bin/bash
# edge — primary router between OUTSIDE and the DMZ
#
# eth1: 203.0.113.1/29 (OUTSIDE)
# eth2: 172.16.0.1/24  (DMZ)
#
# Plain router (this is the enterprise-dmz placement with the firewall
# policy stripped out — the lab is about the load balancer, not nftables
# filtering). Task 5 adds a NAT-mode load-balancing rule here; the VIP
# is this router's outside address, 203.0.113.1.

ip link set eth1 up
ip addr add 203.0.113.1/29 dev eth1 2>/dev/null || true
ip link set eth2 up
ip addr add 172.16.0.1/24 dev eth2 2>/dev/null || true

echo 1 > /proc/sys/net/ipv4/ip_forward

echo "[edge] Ready — 203.0.113.1/29 <-> 172.16.0.1/24, forwarding on"
