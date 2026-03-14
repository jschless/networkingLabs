#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.20.20.10/24 dev eth1
ip route replace default via 10.20.20.1

echo "[source1] ready at 10.20.20.10/24"
echo "[source1] send stream with: socat -u /dev/zero UDP4-DATAGRAM:239.1.1.1:5000,ip-multicast-ttl=8"
