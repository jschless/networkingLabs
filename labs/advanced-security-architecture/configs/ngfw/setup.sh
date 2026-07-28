#!/usr/bin/env bash
set -euo pipefail
ip addr add 198.51.100.2/30 dev eth1
ip addr add 10.114.30.1/24 dev eth3
ip addr add 10.114.40.1/24 dev eth4
ip addr add 10.114.60.1/24 dev eth5
for interface in eth1 eth2 eth3 eth4 eth5; do ip link set "$interface" up; done
ip link add link eth2 name eth2.110 type vlan id 110
ip link add link eth2 name eth2.120 type vlan id 120
ip addr add 10.114.254.1/30 dev eth2.110
ip addr add 10.114.254.5/30 dev eth2.120
ip link set eth2.110 up
ip link set eth2.120 up
ip link add MGMT type vrf table 1050
ip link set MGMT up
ip link set eth6 master MGMT
ip addr add 10.114.50.1/24 dev eth6
ip link set eth6 up
sysctl -qw net.ipv4.ip_forward=1
sysctl -qw net.ipv4.conf.all.rp_filter=0
ip route replace 10.114.10.0/24 via 10.114.254.2
ip route replace 10.114.20.0/24 via 10.114.254.6
ip route replace default via 198.51.100.1
LAB_ROLE=management LAB_PORT=8443 nohup ip vrf exec MGMT python3 /opt/lab/http_service.py >/tmp/mgmt.log 2>&1 &
