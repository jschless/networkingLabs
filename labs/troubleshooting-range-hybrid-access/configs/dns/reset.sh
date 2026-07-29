#!/bin/sh
set -eu
ip link set eth1 down
ip addr flush dev eth1
ip link set eth1 up
ip addr add 10.70.53.53/24 dev eth1
ip -6 addr add 2001:db8:70:53::53/64 dev eth1 nodad
ip route replace default via 10.70.53.1
ip -6 route replace default via 2001:db8:70:53::1
if [ -f /run/range-dnsmasq.pid ]; then
    kill "$(cat /run/range-dnsmasq.pid)" 2>/dev/null || true
fi
rm -f /run/range-dnsmasq.pid
dnsmasq --conf-file=/opt/range/golden/dnsmasq.conf
