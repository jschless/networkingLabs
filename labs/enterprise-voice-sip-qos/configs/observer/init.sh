#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.109.30.60/24 dev eth1
ip route replace default via 10.109.30.1 dev eth1
printf 'nameserver 10.109.30.53\nsearch voice.lab\n' >/etc/resolv.conf
mkdir -p /captures /run/voice
