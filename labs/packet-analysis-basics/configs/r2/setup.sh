#!/bin/bash
set -e

echo 1 > /proc/sys/net/ipv4/ip_forward
ip link set eth1 up
ip link set eth2 up

# FRR is already started by the container entrypoint; apply interface config after links exist.
vtysh -b

echo "[r2] OSPF active"
