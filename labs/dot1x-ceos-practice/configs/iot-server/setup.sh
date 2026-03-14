#!/bin/bash

set -e

ip link set eth1 up
ip addr add 10.30.30.1/24 dev eth1 2>/dev/null || true

echo "[iot-server] 10.30.30.1/24 ready"
