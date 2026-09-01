#!/usr/bin/env bash
set -euo pipefail

ip address replace 203.0.113.6/30 dev eth1
ip link set eth1 up
ip address replace 192.168.2.1/24 dev eth2
ip link set eth2 up
ip route replace default via 203.0.113.5 dev eth1

install -m 0644 /opt/flexvpn-basics/initial-ipsec.conf /etc/ipsec.conf
install -m 0600 /dev/null /etc/ipsec.secrets
ipsec stop >/dev/null 2>&1 || true
