#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 192.168.99.10/24 dev eth1
echo "[admin1] Ready: 192.168.99.10/24"
