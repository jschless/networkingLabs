#!/bin/sh
set -eu
ip link set eth1 down
ip addr flush dev eth1
ip link set eth1 up
ip addr add 10.70.10.10/24 dev eth1
ip -6 addr add 2001:db8:70:10::10/64 dev eth1 nodad
ip route replace default via 10.70.10.1
ip -6 route replace default via 2001:db8:70:10::1
ip neigh flush all >/dev/null 2>&1 || true
ip -6 neigh flush all >/dev/null 2>&1 || true
sed '/hybrid\\.test/d' /etc/hosts >/tmp/range-hosts
: >/etc/hosts
cat /tmp/range-hosts >>/etc/hosts
rm -f /tmp/range-hosts
