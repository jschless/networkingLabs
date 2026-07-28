#!/usr/bin/env bash
set -euxo pipefail

ip addr replace 10.111.40.10/24 dev eth1
ip link set eth1 mtu 1500
ip link set eth1 up
