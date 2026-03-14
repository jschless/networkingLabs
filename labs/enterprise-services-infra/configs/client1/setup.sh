#!/bin/bash
set -e

ip link set eth1 up
ip addr flush dev eth1
dhclient -v -1 eth1 || true

echo "[client1] user workstation ready for DHCP relay testing"
