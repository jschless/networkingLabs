#!/bin/bash
set -e
ip link set eth1 up
ip -6 addr replace 2001:db8:10::53/64 dev eth1
dnsmasq --keep-in-foreground --log-facility=/tmp/dnsmasq.log >/tmp/dnsmasq.out 2>&1 &
echo "[dns1] DNS ready on 2001:db8:10::53"
