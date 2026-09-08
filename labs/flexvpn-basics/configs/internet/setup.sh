#!/usr/bin/env bash
set -euo pipefail

ip address replace 203.0.113.2/30 dev eth1
ip link set eth1 up
ip address replace 203.0.113.5/30 dev eth2
ip link set eth2 up
ip address replace 203.0.113.9/30 dev eth3
ip link set eth3 up

iptables -w 2 -F FORWARD
iptables -w 2 -P FORWARD DROP
iptables -w 2 -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED \
    -m comment --comment FLEXVPN_PUBLIC_ESTABLISHED -j ACCEPT
iptables -w 2 -A FORWARD -p udp -m multiport --dports 500,4500 \
    -s 203.0.113.0/24 -d 203.0.113.0/24 \
    -m comment --comment FLEXVPN_PUBLIC_IKE -j ACCEPT
iptables -w 2 -A FORWARD -p esp -s 203.0.113.0/24 -d 203.0.113.0/24 \
    -m comment --comment FLEXVPN_PUBLIC_ESP -j ACCEPT
iptables -w 2 -A FORWARD -s 192.168.0.0/16 \
    -m comment --comment FLEXVPN_BLOCK_PRIVATE_SOURCE -j DROP
iptables -w 2 -A FORWARD -d 192.168.0.0/16 \
    -m comment --comment FLEXVPN_BLOCK_PRIVATE_DESTINATION -j DROP
iptables -w 2 -A FORWARD -s 203.0.113.0/24 -d 203.0.113.0/24 \
    -m comment --comment FLEXVPN_PUBLIC_UNDERLAY -j ACCEPT
