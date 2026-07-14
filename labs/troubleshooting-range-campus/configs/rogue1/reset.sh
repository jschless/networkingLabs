#!/usr/bin/env sh
set -eu
ip link set eth1 up
ip addr flush dev eth1 scope global || true
ip route del default 2>/dev/null || true
