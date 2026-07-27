#!/usr/bin/env bash
set -euo pipefail
P="clab-enterprise-voice-sip-qos"

docker exec "$P-pbx" sed -i \
    's/external_media_address=10.109.30.10/external_media_address=192.0.2.110/' \
    /etc/asterisk/pjsip.conf
HANDLE="$(docker exec "$P-wan-edge" nft -a list chain ip voice_edge forward_filter \
    | awk '/break-private-sdp/{print $NF; exit}')"
if [[ "$HANDLE" =~ ^[0-9]+$ ]]; then
    docker exec "$P-wan-edge" nft delete rule ip voice_edge forward_filter handle "$HANDLE"
fi
docker exec "$P-pbx" pkill asterisk
docker exec -d "$P-pbx" asterisk -f
for _ in $(seq 1 20); do
    docker exec "$P-pbx" asterisk -rx 'core show version' >/dev/null 2>&1 && break
    sleep 1
done
docker exec "$P-wan-edge" rm -f /run/voice/break-state
echo "Break-It repaired: remote media again uses the stateful edge address."
