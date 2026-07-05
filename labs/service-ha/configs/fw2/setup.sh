#!/bin/bash
# fw2 — firewall node 2 (the default BACKUP). Mirror of fw1 with .3 addresses.
ip addr replace 10.10.0.3/24  dev eth1
ip addr replace 10.10.20.3/24 dev eth2
ip addr replace 10.10.99.2/30 dev eth3
ip link set eth1 up; ip link set eth2 up; ip link set eth3 up

sysctl -w net.ipv4.ip_forward=1 >/dev/null
sysctl -w net.netfilter.nf_conntrack_tcp_loose=0 >/dev/null

echo "[fw2] eth1=10.10.0.3 eth2=10.10.20.3 eth3=10.10.99.2; ip_forward=1, tcp_loose=0"
