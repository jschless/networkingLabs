#!/usr/bin/env bash
set -eu
/usr/local/bin/busybox ip addr add 10.90.30.10/24 dev eth1
/usr/local/bin/busybox ip link set eth1 up
/usr/local/bin/busybox ip route replace default via 10.90.30.1
