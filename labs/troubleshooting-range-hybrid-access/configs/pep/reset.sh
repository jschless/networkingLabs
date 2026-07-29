#!/bin/sh
set -eu
ip link set eth1 down
ip addr flush dev eth1
ip link set eth1 up
ip addr add 10.70.30.30/24 dev eth1
ip -6 addr add 2001:db8:70:30::30/64 dev eth1 nodad
ip route replace default via 10.70.30.1
ip -6 route replace default via 2001:db8:70:30::1
if [ -f /run/range-pep.pid ]; then
    kill "$(cat /run/range-pep.pid)" 2>/dev/null || true
fi
python3 /opt/range/pep_proxy.py >/run/range-pep.log 2>&1 &
echo "$!" >/run/range-pep.pid
