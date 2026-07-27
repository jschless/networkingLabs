#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.109.40.20/24 dev eth1
ip route replace default via 10.109.40.1 dev eth1
printf 'nameserver 10.109.30.53\nsearch voice.lab\n' >/etc/resolv.conf
mkdir -p /run/voice
nohup iperf3 -s >/var/log/iperf3-server.log 2>&1 &
printf 'UNREGISTERED\n' >/run/voice/state
