#!/usr/bin/env bash
set -eu
for pair in 'eth1 10.90.10.1/24' 'eth2 10.90.20.1/24' 'eth3 10.90.30.1/24' 'eth4 10.90.40.1/24' 'eth5 10.90.50.1/24'; do
  set -- $pair; ip addr add "$2" dev "$1"; ip link set "$1" up
done
sysctl -w net.ipv4.ip_forward=1 >/dev/null
# Deliberately open at first. Students install the origin-boundary policy.
nft flush ruleset
