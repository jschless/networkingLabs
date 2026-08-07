#!/bin/sh
# c1 — site-1 client (behind r1)
set -eu

for _attempt in $(seq 1 60); do
    ip link show eth1 >/dev/null 2>&1 && break
    sleep 1
done
if ! ip link show eth1 >/dev/null 2>&1; then
    echo "c1 setup: eth1 did not appear within 60 seconds" >&2
    ip -brief link >&2 || true
    exit 1
fi

ip addr replace 172.16.1.10/24 dev eth1
# replace, not add: containerlab already installed a default route via
# the management network, and `ip route add default` would silently fail
ip route replace default via 172.16.1.1
