#!/usr/bin/env bash
set -euo pipefail
ip link set eth1 up
ip addr flush dev eth1
printf 'nameserver 10.109.30.53\nsearch voice.lab\n' >/etc/resolv.conf
mkdir -p /run/voice
