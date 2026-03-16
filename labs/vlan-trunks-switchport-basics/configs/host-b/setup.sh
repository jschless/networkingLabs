#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.10.10.12/24 dev eth1
echo "[host-b] Ready: 10.10.10.12/24"
