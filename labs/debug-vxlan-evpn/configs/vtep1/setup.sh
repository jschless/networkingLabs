#!/bin/bash
# vtep1 setup: create VXLAN interface and Linux bridge for VNI 100
#
# This script:
#   1. Adds the loopback IP manually (needed before vxlan creation,
#      since 'ip link add vxlan ... local <IP>' requires the IP to exist)
#   2. Creates vxlan100 with nolearning (rely on BGP EVPN for MAC/IP)
#   3. Creates bridge br100 and adds vxlan100 + eth2 (host port)
#   4. Runs vtysh -b to load FRR OSPF + BGP EVPN config

set -e

# Step 1: Add loopback IP (FRR will also add it via vtysh -b — that's fine)
ip addr add 10.0.0.1/32 dev lo 2>/dev/null || true

# Step 2: Create VXLAN interface
#   id 100        = VNI (VXLAN Network Identifier)
#   dstport 4789  = standard VXLAN UDP port
#   local 10.0.0.1 = our VTEP IP (loopback)
#   nolearning    = disable data-plane MAC learning; rely on BGP EVPN
ip link add vxlan100 type vxlan id 100 dstport 4789 local 10.0.0.1 nolearning 2>/dev/null || true
ip link set vxlan100 up

# Step 3: Create bridge and add VXLAN + host-facing port
ip link add br100 type bridge 2>/dev/null || true
ip link set br100 up
ip link set vxlan100 master br100
ip link set eth2 master br100   # eth2 connects to host1

# Step 4: Load FRR config (OSPF underlay + BGP EVPN)
vtysh -b
