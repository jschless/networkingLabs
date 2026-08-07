#!/bin/sh
set -eu

for _attempt in $(seq 1 60); do
    ip link show eth1 >/dev/null 2>&1 && break
    sleep 1
done
if ! ip link show eth1 >/dev/null 2>&1; then
    echo "host2 setup: eth1 did not appear within 60 seconds" >&2
    exit 1
fi

ip link set dev eth1 down
ip link set dev eth1 address 02:00:00:00:02:02
ip addr flush dev eth1
ip addr add 172.16.0.2/24 dev eth1
ip link set dev eth1 up
