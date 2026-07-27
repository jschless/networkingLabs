#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
P="clab-enterprise-voice-sip-qos"
DURATION="${1:-12}"
LABEL="${2:-last}"
[[ "$DURATION" =~ ^[0-9]+$ ]] && (( DURATION >= 5 && DURATION <= 70 )) \
    || { echo "duration must be an integer from 5 through 70 seconds" >&2; exit 2; }
[[ "$LABEL" =~ ^[a-zA-Z0-9_-]+$ ]] || { echo "invalid capture label" >&2; exit 2; }

TEMP_DIR="$(mktemp -d)"
cleanup() {
    docker exec "$P-pbx" pkill -INT tcpdump >/dev/null 2>&1 || true
    docker exec "$P-phone-b" pkill -INT tcpdump >/dev/null 2>&1 || true
    docker exec "$P-phone-a" pkill sipp >/dev/null 2>&1 || true
    docker exec "$P-phone-b" pkill sipp >/dev/null 2>&1 || true
    rm -r "$TEMP_DIR"
}
trap cleanup EXIT

"$LAB_DIR/register-endpoints.sh" >/tmp/enterprise-voice-register.log
PHONE_A_IP="$(docker exec "$P-phone-a" ip -4 -o addr show dev eth1 | awk '{print $4}' | cut -d/ -f1)"
docker exec "$P-phone-a" sh -c \
    "sed 's/CALL_DURATION_MS/$((DURATION * 1000))/' /opt/voice/phone-a-uac.xml >/tmp/phone-a-uac.xml"

for node in pbx phone-b; do
    docker exec "$P-$node" pkill -INT tcpdump >/dev/null 2>&1 || true
    docker exec "$P-$node" rm -f "/tmp/$LABEL.pcap"
    docker exec -d "$P-$node" tcpdump -U -n -i eth1 -w "/tmp/$LABEL.pcap" \
      'udp port 5060 or udp portrange 6000-10100'
done

docker exec "$P-phone-b" pkill sipp >/dev/null 2>&1 || true
docker exec -d "$P-phone-b" sipp 10.109.30.10:5060 \
    -sf /opt/voice/phone-b-uas.xml -i 10.109.40.20 -p 5060 \
    -mi 10.109.40.20 -min_rtp_port 6002 -max_rtp_port 6002 \
    -m 1 -nostdin -nr -trace_msg -message_file "/tmp/$LABEL-phone-b-sip.log" \
    -trace_err -error_file "/tmp/$LABEL-phone-b-errors.log" -timeout 75s
sleep 1

docker exec "$P-phone-a" sipp 10.109.30.10:5060 \
    -sf /tmp/phone-a-uac.xml -i "$PHONE_A_IP" -p 5060 \
    -mi "$PHONE_A_IP" -min_rtp_port 6000 -max_rtp_port 6000 \
    -s 2002 -m 1 -nostdin -nr \
    -trace_msg -message_file "/tmp/$LABEL-phone-a-sip.log" \
    -trace_err -error_file "/tmp/$LABEL-phone-a-errors.log" -timeout 75s \
    >/tmp/"$LABEL"-phone-a-screen.log 2>&1

for node in pbx phone-b; do
    docker exec "$P-$node" pkill -INT tcpdump >/dev/null 2>&1 || true
done
sleep 1

for node in pbx phone-b; do
    docker cp "$P-$node:/tmp/$LABEL.pcap" "$TEMP_DIR/$node.pcap" >/dev/null
    docker cp "$TEMP_DIR/$node.pcap" "$P-observer:/captures/$LABEL-$node.pcap" >/dev/null
    docker exec "$P-observer" rtp-analyze --json "/captures/$LABEL-$node.pcap" \
      >"$TEMP_DIR/$node.json"
    docker cp "$TEMP_DIR/$node.json" "$P-observer:/captures/$LABEL-$node.json" >/dev/null
done

docker exec "$P-pbx" asterisk -rx 'core show channels concise'
docker exec "$P-observer" sh -c \
    "echo PBX_RTP; rtp-analyze /captures/$LABEL-pbx.pcap; \
     echo REMOTE_RTP; rtp-analyze /captures/$LABEL-phone-b.pcap"
