#!/bin/bash
# router/setup.sh — Configure IP addresses and enable IP forwarding
# This runs automatically at container start via exec in topology.yml

# Bring up interfaces and assign IPs
ip link set eth1 up && ip addr add 10.1.1.2/30 dev eth1
ip link set eth2 up && ip addr add 10.1.2.2/30 dev eth2
ip link set eth3 up && ip addr add 10.1.3.2/30 dev eth3
ip link set eth4 up && ip addr add 10.2.0.1/30 dev eth4

# Enable IP forwarding (also set via sysctl in topology, belt-and-suspenders)
echo 1 > /proc/sys/net/ipv4/ip_forward

# Ensure routes for each subnet are present
ip route add 10.1.1.0/30 dev eth1 2>/dev/null || true
ip route add 10.1.2.0/30 dev eth2 2>/dev/null || true
ip route add 10.1.3.0/30 dev eth3 2>/dev/null || true
ip route add 10.2.0.0/30 dev eth4 2>/dev/null || true

echo "[router] IP addressing done. Forwarding enabled."
echo "[router] Run:  bash /qos-apply.sh   to enable HTB QoS on eth4"
echo "[router] Run:  bash /qos-show.sh    to view class stats"
echo "[router] Run:  bash /qos-remove.sh  to remove QoS"
