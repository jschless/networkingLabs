#!/bin/bash
set -e

ip link set eth1 up
ip addr flush dev eth1
# Request DHCP asynchronously so deploy can complete before services1 comes up.
dhclient -v eth1 >/tmp/dhclient.log 2>&1 &

echo "[client1] user workstation ready for DHCP relay testing"
