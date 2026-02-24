#!/bin/bash
# PE2 post-start setup: create Linux VRF and reload FRR config
# Runs after containerlab creates veth pairs (exec phase)
set -e
ip link add CUST-A type vrf table 100 2>/dev/null || true
ip link set CUST-A up
ip link set eth2 master CUST-A
vtysh -b 2>/dev/null || true
