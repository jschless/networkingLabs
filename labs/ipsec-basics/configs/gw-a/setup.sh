#!/bin/bash
# gw-a — Site A gateway / IPsec endpoint
#
# Pre-configured: IP addressing and WAN reachability
# You configure:  /etc/ipsec.conf, /etc/ipsec.secrets, then `ipsec start`
#
# LAN A:  192.168.1.1/24  (eth1, facing host-a)
# WAN:    203.0.113.1/30  (eth2, facing internet)
#
# Peer:   gw-b WAN IP = 203.0.113.6
# LAN B:  192.168.2.0/24  (reachable after IPsec tunnel is up)

ip addr add 192.168.1.1/24 dev eth1 2>/dev/null || true
ip link set eth1 up

ip addr add 203.0.113.1/30 dev eth2 2>/dev/null || true
ip link set eth2 up

# Default route via internet node — lets gw-a reach gw-b's public IP
ip route add default via 203.0.113.2 2>/dev/null || true
