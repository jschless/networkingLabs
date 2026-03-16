#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.10.10.53/24 dev eth1
dnsmasq --keep-in-foreground --log-facility=/tmp/dnsmasq.log >/tmp/dnsmasq.out 2>&1 &
echo "[services1] DHCP/DNS ready on 10.10.10.53"
