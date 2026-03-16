#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.10.10.11/24 dev eth1
echo "[host-a] Ready: 10.10.10.11/24"
