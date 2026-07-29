#!/bin/sh
set -eu
ip link set eth1 down
ip addr flush dev eth1
ip link set eth1 up
ip addr add 10.70.41.40/24 dev eth1
ip -6 addr add 2001:db8:70:41::40/64 dev eth1 nodad
ip route replace default via 10.70.41.1
ip -6 route replace default via 2001:db8:70:41::1
if [ -f /run/range-app.pid ]; then
    kill "$(cat /run/range-app.pid)" 2>/dev/null || true
fi
python3 /opt/range/app_server.py origin-a >/run/range-app.log 2>&1 &
echo "$!" >/run/range-app.pid
