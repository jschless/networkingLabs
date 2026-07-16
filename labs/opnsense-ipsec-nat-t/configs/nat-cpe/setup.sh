#!/usr/bin/env bash
set -euo pipefail
ip addr add 198.51.100.1/24 dev eth1
ip addr add 10.200.0.1/24 dev eth2
ip link set eth1 up
ip link set eth2 up
sysctl -w net.ipv4.ip_forward=1 >/dev/null
iptables -t nat -A POSTROUTING -s 10.200.0.0/24 -o eth1 -j MASQUERADE
for port in 500 4500; do
  iptables -t nat -A PREROUTING -i eth1 -p udp --dport "$port" -j DNAT --to-destination 10.200.0.2
done
echo "nat-cpe: 10.200.0.2 is NATed to 198.51.100.1; IKE ports forwarded"
