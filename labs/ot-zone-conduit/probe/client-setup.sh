#!/usr/bin/env bash
set -euo pipefail
ip addr replace 10.250.10.2/24 dev eth1
ip link set eth1 up
ip route replace 10.250.20.0/24 via 10.250.10.1
