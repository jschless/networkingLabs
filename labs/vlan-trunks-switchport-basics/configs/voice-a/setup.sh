#!/bin/bash
set -e
ip link set eth1 up
ip addr replace 10.20.20.11/24 dev eth1
echo "[voice-a] Ready: 10.20.20.11/24"
