#!/usr/bin/env bash
set -eu
ip addr add 10.112.31.2/30 dev eth1
ip addr add 10.112.32.2/30 dev eth2
ip route add 10.112.10.0/24 via 10.112.31.1 dev eth1
ip route add 10.112.20.0/24 via 10.112.32.1 dev eth2
mkdir -p /var/lib/gitops-observer
printf 'observer-ready\n' > /var/lib/gitops-observer/status
