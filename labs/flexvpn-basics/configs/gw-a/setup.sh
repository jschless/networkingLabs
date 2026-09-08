#!/usr/bin/env bash
set -euo pipefail

ip address replace 192.168.1.1/24 dev eth1
ip link set eth1 up
ip address replace 203.0.113.1/30 dev eth2
ip link set eth2 up
ip route replace default via 203.0.113.2 dev eth2

install -m 0644 /opt/flexvpn-basics/hub-ipsec.conf /etc/ipsec.conf
install -m 0600 /opt/flexvpn-basics/hub-ipsec.secrets /etc/ipsec.secrets

ip tunnel del vti1 2>/dev/null || true
ip tunnel del vti2 2>/dev/null || true
ip tunnel add vti1 mode vti local 203.0.113.1 remote 203.0.113.6 key 1
ip tunnel add vti2 mode vti local 203.0.113.1 remote 203.0.113.10 key 2
ip link set vti1 up
ip link set vti2 up
ip address replace 10.10.1.1/30 dev vti1
ip address replace 10.10.2.1/30 dev vti2
sysctl -qw net.ipv4.conf.vti1.disable_policy=1
sysctl -qw net.ipv4.conf.vti2.disable_policy=1
sysctl -qw net.ipv4.conf.vti1.rp_filter=0
sysctl -qw net.ipv4.conf.vti2.rp_filter=0
ip route replace 192.168.2.0/24 via 10.10.1.2 dev vti1
ip route replace 192.168.3.0/24 via 10.10.2.2 dev vti2

ipsec start
