#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.10.10.10/24 dev eth1
ip route replace default via 10.10.10.1
echo "[client-a] Ready: 10.10.10.10/24 via 10.10.10.1"
