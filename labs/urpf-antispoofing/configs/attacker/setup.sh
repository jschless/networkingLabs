#!/bin/bash
set -e

ip link set eth1 up
ip addr replace 10.10.1.1/30 dev eth1
ip addr replace 10.0.0.10/32 dev lo
ip addr replace 10.99.99.1/32 dev lo
ip addr replace 10.88.88.1/32 dev lo
ip route replace default via 10.10.1.2

# Give the VyOS neighbor a bounded window to finish startup and populate ARP.
# A slow response must not turn endpoint setup itself into a deployment error.
for _ in {1..20}; do
    if ping -c 1 -W 1 10.10.1.2 >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo "[attacker] Ready: link 10.10.1.1/30, legitimate source 10.0.0.10"
