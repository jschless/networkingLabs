#!/usr/bin/env bash
# internet — deterministic public-only transit between the two WAN segments.
set -euo pipefail

ip addr add 203.0.113.2/30 dev eth1 2>/dev/null || true
ip link set eth1 up

ip addr add 203.0.113.5/30 dev eth2 2>/dev/null || true
ip link set eth2 up

# The routed RFC 1918 paths exist on the gateways so that policy IPsec has a
# valid route to intercept. This transit policy makes the before-state safe:
# clear-text private traffic cannot cross, while public IKE/ESP traffic can.
iptables -w 5 -F FORWARD
iptables -w 5 -P FORWARD DROP
iptables -w 5 -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED \
    -m comment --comment IPSEC_PUBLIC_ESTABLISHED -j ACCEPT
iptables -w 5 -A FORWARD -p esp -s 203.0.113.0/24 -d 203.0.113.0/24 \
    -m comment --comment IPSEC_PUBLIC_ESP -j ACCEPT
iptables -w 5 -A FORWARD -s 192.168.0.0/16 \
    -m comment --comment IPSEC_BLOCK_PRIVATE_SOURCE -j DROP
iptables -w 5 -A FORWARD -d 192.168.0.0/16 \
    -m comment --comment IPSEC_BLOCK_PRIVATE_DESTINATION -j DROP
iptables -w 5 -A FORWARD -s 203.0.113.0/24 -d 203.0.113.0/24 \
    -m comment --comment IPSEC_PUBLIC_UNDERLAY -j ACCEPT
