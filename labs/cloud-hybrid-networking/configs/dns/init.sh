#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.63.10.53/24 dev eth1
ip link set eth1 up
