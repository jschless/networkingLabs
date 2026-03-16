#!/bin/bash
set -e

ip link set eth1 up
ip link set eth1 promisc on

echo "[analyzer] Ready for tcpdump/tshark on eth1"
