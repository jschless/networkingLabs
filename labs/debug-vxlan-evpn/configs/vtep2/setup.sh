#!/bin/bash
# vtep2 setup: create VXLAN interface and Linux bridge for VNI 100

set -e

# Step 1: Add loopback IP
ip addr add 10.0.0.2/32 dev lo 2>/dev/null || true

# Step 2: Create VXLAN interface (VNI 100, VTEP IP = loopback 10.0.0.2)
ip link add vxlan100 type vxlan id 100 dstport 4789 local 10.0.0.1 nolearning 2>/dev/null || true
ip link set vxlan100 up

# Step 3: Create bridge and add VXLAN + host-facing port
ip link add br100 type bridge 2>/dev/null || true
ip link set br100 up
ip link set vxlan100 master br100
ip link set eth2 master br100   # eth2 connects to host2

# Step 4: Load FRR config (OSPF underlay + BGP EVPN)
vtysh -b
