#!/bin/sh
set -eu

i=0
while ! ip link show eth1 >/dev/null 2>&1; do
    i=$((i + 1))
    [ "$i" -lt 30 ] || { echo "client-video: eth1 unavailable" >&2; exit 1; }
    sleep 1
done

ip link set eth1 up
ip address replace 10.1.2.1/30 dev eth1
ip route replace default via 10.1.2.2 dev eth1
