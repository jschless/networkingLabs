#!/bin/bash

set -e

ip link set eth1 up
ip addr add 10.20.20.1/24 dev eth1 2>/dev/null || true

echo "[contractor-server] 10.20.20.1/24 ready"
