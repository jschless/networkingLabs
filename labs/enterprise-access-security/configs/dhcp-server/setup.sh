#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.10.10.10/24 dev eth1
dnsmasq --conf-file=/etc/dnsmasq.d/lab.conf

echo "[dhcp-server] serving VLAN 10 leases from 10.10.10.100-150"
