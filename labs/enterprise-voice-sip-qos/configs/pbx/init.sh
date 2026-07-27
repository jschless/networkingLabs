#!/usr/bin/env bash
set -euo pipefail
ip addr add 10.109.30.10/24 dev eth1
ip route replace default via 10.109.30.1 dev eth1
mkdir -p /run/voice /var/log/asterisk /var/run/asterisk
for file in pjsip.conf extensions.conf rtp.conf logger.conf modules.conf; do
    cp "/opt/voice/$file" "/etc/asterisk/$file"
done
asterisk -f >/var/log/asterisk/console.log 2>&1 &
for _ in $(seq 1 20); do
    asterisk -rx 'core show version' >/dev/null 2>&1 && exit 0
    sleep 1
done
exit 1
