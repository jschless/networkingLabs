#!/usr/bin/env bash
set -eu
ip addr add "$IP_ADDR" dev eth1
ip link set eth1 up
ip route replace default via "$GATEWAY"
