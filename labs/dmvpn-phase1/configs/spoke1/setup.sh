#!/bin/bash
# spoke1 setup — WAN IP + GRE tunnel to hub

# Remove management default route
ip route del default dev eth0 2>/dev/null || true

# WAN interface
ip addr add 10.0.0.11/24 dev eth1 2>/dev/null || true
ip link set eth1 up

# Create GRE tunnel to hub
ip tunnel add dmvpn0 mode gre local 10.0.0.11 remote 10.0.0.1 key 0 dev eth1 2>/dev/null || true
ip addr add 172.16.0.11/24 dev dmvpn0 2>/dev/null || true
ip link set dmvpn0 up

# Load FRR config (after interfaces exist)
vtysh -b
