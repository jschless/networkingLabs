#!/usr/bin/env bash
set -euxo pipefail

ip addr replace 10.111.10.21/24 dev eth1
ip addr replace 10.111.20.21/24 dev eth2
ip addr replace 10.111.30.21/24 dev eth3
ip link set eth1 mtu 1500
ip link set eth2 mtu 1500
ip link set eth3 mtu 1500
ip link set eth1 up
ip link set eth2 up
ip link set eth3 up
iperf3 -s -D
printf 'STANDBY-NO-SHARED-LUN\n' >/run/storage-target-state
