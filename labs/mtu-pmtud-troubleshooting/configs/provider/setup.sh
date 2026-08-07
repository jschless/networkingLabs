#!/usr/bin/env bash
set -euo pipefail

sysctl -q -w net.ipv4.ip_forward=1

ip link set dev eth1 up mtu 1400
ip link set dev eth2 up mtu 1400
ip -4 addr flush dev eth1
ip -4 addr flush dev eth2
ip addr add 203.0.113.2/30 dev eth1
ip addr add 203.0.113.5/30 dev eth2

if ! iptables -C OUTPUT -p icmp --icmp-type fragmentation-needed \
  -m comment --comment PMTUD_FEEDBACK_BLACKHOLE -j DROP 2>/dev/null; then
  iptables -A OUTPUT -p icmp --icmp-type fragmentation-needed \
    -m comment --comment PMTUD_FEEDBACK_BLACKHOLE -j DROP
fi

echo "[provider] Transit service is ready."
