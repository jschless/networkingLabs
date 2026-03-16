#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.20.20.12/24 dev eth1
echo "[voice-b] Ready: 10.20.20.12/24"
