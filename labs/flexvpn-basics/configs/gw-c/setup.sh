#!/bin/bash
# gw-c — FlexVPN Spoke2 (practice node)
#
# Pre-configured: IP addressing and WAN reachability only.
# Your task: create the VTI interface, configure IKEv2, start ipsec.
# See README.md — Task 5 for step-by-step instructions.
#
# WAN:    203.0.113.10/30  (eth1, facing internet)
# LAN C:  192.168.3.1/24   (eth2, facing host-c)
# Hub WAN IP: 203.0.113.1
#
# VTI you will create:
#   vti0  local 203.0.113.10 remote 203.0.113.1 key 2
#   addr  10.10.2.2/30

ip addr add 203.0.113.10/30 dev eth1 2>/dev/null || true
ip link set eth1 up

ip addr add 192.168.3.1/24 dev eth2 2>/dev/null || true
ip link set eth2 up

# Default route via internet node
ip route del default dev eth0 2>/dev/null || true
ip route add default via 203.0.113.9 2>/dev/null || true

# VTI module loaded and ready; VTI interface creation is your task
modprobe ip_vti 2>/dev/null || true
