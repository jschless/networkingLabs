#!/usr/bin/env bash
set -euo pipefail
P="clab-enterprise-voice-sip-qos"

docker exec "$P-pbx" sed -i \
    's/external_media_address=192.0.2.110/external_media_address=10.109.30.10/' \
    /etc/asterisk/pjsip.conf
docker exec "$P-wan-edge" nft insert rule ip voice_edge forward_filter \
    iifname eth2 oifname eth1 ip saddr 10.109.40.20 ip daddr 10.109.30.10 \
    udp dport 10000-10099 counter drop comment break-private-sdp
docker exec "$P-pbx" pkill asterisk
docker exec -d "$P-pbx" asterisk -f
for _ in $(seq 1 20); do
    docker exec "$P-pbx" asterisk -rx 'core show version' >/dev/null 2>&1 && break
    sleep 1
done
printf 'PRIVATE_SDP\n' | docker exec -i "$P-wan-edge" sh -c 'cat >/run/voice/break-state'
echo "Break-It active: remote SDP advertises a PBX-private media address rejected at the untrusted edge."
