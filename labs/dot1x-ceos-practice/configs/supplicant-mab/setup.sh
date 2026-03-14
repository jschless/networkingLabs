#!/bin/bash

set -e

ip link set eth1 up
ip addr add 10.30.30.11/24 dev eth1 2>/dev/null || true

echo "[supplicant-mab] IP 10.30.30.11/24 configured on eth1"
sleep 8
ping -c 2 -W 2 10.30.30.1 2>/dev/null || true
