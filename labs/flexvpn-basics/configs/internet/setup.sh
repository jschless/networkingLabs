#!/bin/bash
# internet — simulated public internet (three-way transit router)
# Pre-configured: all three WAN interfaces, IP forwarding via sysctl in topology.clab.yml.
# Routes all three WAN segments; no default route needed (only connected routes).

ip addr add 203.0.113.2/30 dev eth1 2>/dev/null || true   # link to gw-a
ip link set eth1 up

ip addr add 203.0.113.5/30 dev eth2 2>/dev/null || true   # link to gw-b
ip link set eth2 up

ip addr add 203.0.113.9/30 dev eth3 2>/dev/null || true   # link to gw-c
ip link set eth3 up
