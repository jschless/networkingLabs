#!/bin/bash
set -e
ip link set eth1 up
sysctl -w net.ipv6.conf.eth1.accept_ra=2 >/dev/null
echo "[client1] Waiting for router advertisements on eth1"
