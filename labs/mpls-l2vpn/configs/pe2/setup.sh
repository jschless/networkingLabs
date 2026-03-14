#!/bin/bash
# pe2 post-start setup: create L2VPN bridge infrastructure, then load FRR config
#
# Mirror of pe1/setup.sh but CE-facing port is eth2 (not eth1).
#
# After this script:
#   ce2 <-> eth2 <-> br-l2vpn <-> pw0 <-> [MPLS label stack] <-> pe1 <-> ce1
#
set -e

# Step 1: bring up the attachment circuit (CE-facing port) — no IP, L2 only
ip link set eth2 up

# Step 2: create the L2VPN bridge
ip link add br-l2vpn type bridge 2>/dev/null || true
ip link set br-l2vpn up

# Step 3: create pseudowire dummy interface
ip link add pw0 type dummy 2>/dev/null || true
ip link set pw0 up

# Step 4: add both ports to the bridge
ip link set eth2  master br-l2vpn
ip link set pw0   master br-l2vpn

# Step 5: load FRR config
vtysh -b 2>/dev/null || true
