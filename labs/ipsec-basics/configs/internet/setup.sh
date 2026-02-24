#!/bin/bash
# internet — simulated public internet (just a router between WAN segments)
# Pre-configured: both WAN interfaces, IP forwarding via sysctl in topology.yml

ip addr add 203.0.113.2/30 dev eth1 2>/dev/null || true
ip link set eth1 up

ip addr add 203.0.113.5/30 dev eth2 2>/dev/null || true
ip link set eth2 up
