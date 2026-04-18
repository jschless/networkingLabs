#!/bin/bash
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward

ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
ip link set eth4 up

ip addr add 10.10.10.1/24 dev eth1
ip addr add 172.16.10.1/24 dev eth2
ip addr add 172.16.20.1/24 dev eth3

iptables -P FORWARD DROP
iptables -F FORWARD
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -s 10.10.10.0/24 -d 172.16.10.0/24 -j ACCEPT
iptables -A FORWARD -s 10.10.10.0/24 -d 172.16.20.0/24 -j ACCEPT
iptables -A FORWARD -s 172.16.10.0/24 -d 10.10.10.0/24 -j ACCEPT
iptables -A FORWARD -s 172.16.20.0/24 -d 10.10.10.0/24 -j ACCEPT

for iface in eth1 eth2 eth3; do
  tc qdisc add dev "$iface" ingress handle ffff: 2>/dev/null || true
  tc filter add dev "$iface" parent ffff: protocol all u32 match u32 0 0 \
    action mirred egress mirror dev eth4 2>/dev/null || true
done

echo "[router-fw] routed attacker and DMZ segments, mirrored eth1/eth2/eth3 to eth4"
