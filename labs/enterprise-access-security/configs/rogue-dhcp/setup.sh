#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.10.10.250/24 dev eth1
dnsmasq --conf-file=/etc/dnsmasq.d/lab.conf

echo "[rogue-dhcp] advertising bad leases on VLAN 10"
