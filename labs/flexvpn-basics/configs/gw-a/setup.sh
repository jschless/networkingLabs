#!/bin/bash
# gw-a — FlexVPN Hub (fully pre-configured)
#
# This node is the IKEv2 FlexVPN hub. It has:
#   - One VTI per spoke (vti1 for spoke1/gw-b, vti2 for spoke2/gw-c)
#   - IKEv2 PSK connections defined in /etc/ipsec.conf
#   - OSPF over the VTIs to distribute LAN routes dynamically
#
# LAN A:  192.168.1.1/24  (eth1)
# WAN:    203.0.113.1/30  (eth2)
# VTI1:   10.10.1.1/30    (hub side of hub↔spoke1 tunnel)
# VTI2:   10.10.2.1/30    (hub side of hub↔spoke2 tunnel)

# --- Physical interfaces ---
ip addr add 192.168.1.1/24 dev eth1 2>/dev/null || true
ip link set eth1 up

ip addr add 203.0.113.1/30 dev eth2 2>/dev/null || true
ip link set eth2 up

# Default route via internet node
ip route del default dev eth0 2>/dev/null || true
ip route add default via 203.0.113.2 2>/dev/null || true

# --- VTI interfaces ---
# Load the VTI kernel module (ip_vti)
modprobe ip_vti 2>/dev/null || true

# VTI1: hub <-> spoke1 (gw-b at 203.0.113.6), mark=1
ip tunnel add vti1 mode vti local 203.0.113.1 remote 203.0.113.6 key 1 2>/dev/null || true
ip link set vti1 up
ip addr add 10.10.1.1/30 dev vti1 2>/dev/null || true
# disable_policy: VTI handles its own XFRM mark; let kernel route freely over it
sysctl -w net.ipv4.conf.vti1.disable_policy=1 >/dev/null 2>&1

# VTI2: hub <-> spoke2 (gw-c at 203.0.113.10), mark=2
ip tunnel add vti2 mode vti local 203.0.113.1 remote 203.0.113.10 key 2 2>/dev/null || true
ip link set vti2 up
ip addr add 10.10.2.1/30 dev vti2 2>/dev/null || true
sysctl -w net.ipv4.conf.vti2.disable_policy=1 >/dev/null 2>&1

# --- Start IKEv2 (strongSwan) ---
ipsec start
