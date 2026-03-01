#!/bin/bash
# gw-b — Site B gateway / IPsec endpoint
#
# Pre-configured: IP addressing and WAN reachability
# You configure:  /etc/ipsec.conf, /etc/ipsec.secrets, then `ipsec start`
#
# WAN:    203.0.113.6/30  (eth1, facing internet)
# LAN B:  192.168.2.1/24  (eth2, facing host-b)
#
# Peer:   gw-a WAN IP = 203.0.113.1
# LAN A:  192.168.1.0/24  (reachable after IPsec tunnel is up)

ip addr add 203.0.113.6/30 dev eth1 2>/dev/null || true
ip link set eth1 up

ip addr add 192.168.2.1/24 dev eth2 2>/dev/null || true
ip link set eth2 up

# Default route via internet node — lets gw-b reach gw-a's public IP
ip route del default dev eth0 2>/dev/null || true
ip route add default via 203.0.113.5 2>/dev/null || true
