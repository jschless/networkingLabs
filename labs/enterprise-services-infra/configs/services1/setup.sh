#!/bin/bash
set -e

ip link set eth1 up
ip link add link eth1 name eth1.99 type vlan id 99
ip link set eth1.99 up
ip addr add 192.168.99.10/24 dev eth1.99
ip route replace default via 192.168.99.1

mkdir -p /var/log/remote

chronyd -f /etc/chrony/chrony.conf
rsyslogd
dnsmasq --conf-file=/etc/dnsmasq.d/lab.conf

echo "[services1] DNS/DHCP/NTP/syslog services ready on 192.168.99.10"
