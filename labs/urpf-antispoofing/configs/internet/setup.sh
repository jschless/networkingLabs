#!/bin/bash
set -e

ip link set eth1 up
ip addr replace 10.10.2.2/30 dev eth1
ip route replace default via 10.10.2.1

# Give the VyOS neighbor a bounded window to finish startup and populate ARP.
# A slow response must not turn endpoint setup itself into a deployment error.
for _ in {1..20}; do
    if ping -c 1 -W 1 10.10.2.1 >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo "[internet] Ready: 10.10.2.2/30 via 10.10.2.1"
