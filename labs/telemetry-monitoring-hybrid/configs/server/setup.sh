#!/bin/bash
set -e

ip link set eth1 up
ip addr add 10.20.20.11/24 dev eth1
ip route replace default via 10.20.20.1

nohup iperf3 -s >/var/log/iperf3-server.log 2>&1 &

echo "[server] Ready: 10.20.20.11/24 -> 10.20.20.1, iperf3 server active"
