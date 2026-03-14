#!/bin/bash
# pe1 post-start setup: create L2VPN bridge infrastructure, then load FRR config
#
# What this does:
#   1. Create Linux bridge br-l2vpn — the L2 forwarding domain for the pseudowire
#   2. Add eth1 (CE-facing attachment circuit) to the bridge
#   3. Create pw0 — a dummy interface that FRR/zebra will use as the pseudowire
#      endpoint; once LDP negotiates labels, kernel MPLS routes redirect PW traffic
#      through the MPLS core
#   4. Add pw0 to the bridge so CE traffic exits via the pseudowire and vice versa
#   5. Run vtysh -b to load FRR config (IS-IS + LDP + l2vpn stanza)
#
# After this script:
#   ce1 <-> eth1 <-> br-l2vpn <-> pw0 <-> [MPLS label stack] <-> pe2 <-> ce2
#
set -e

# Step 1: bring up the attachment circuit (CE-facing port) — no IP, L2 only
ip link set eth1 up

# Step 2: create the L2VPN bridge
ip link add br-l2vpn type bridge 2>/dev/null || true
ip link set br-l2vpn up

# Step 3: create pseudowire dummy interface
# FRR zebra will program MPLS label operations associated with this interface
ip link add pw0 type dummy 2>/dev/null || true
ip link set pw0 up

# Step 4: add both ports to the bridge
ip link set eth1  master br-l2vpn
ip link set pw0   master br-l2vpn

# Step 5: load FRR config — starts IS-IS, LDP, l2vpn stanza
vtysh -b 2>/dev/null || true
