#!/usr/bin/env bash
set -eu
ip link add br0 type bridge 2>/dev/null || true
for port in $PORTS; do ip link set "$port" master br0; ip link set "$port" up; done
ip link set br0 up
