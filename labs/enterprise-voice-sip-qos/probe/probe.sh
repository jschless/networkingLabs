#!/usr/bin/env bash
set -euo pipefail

LAB_DIR="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="enterprise-voice-tools:1.0.0"
NETWORK="enterprise-voice-feature-probe"
PREFIX="voice-probe"
PROBE_DIR="$(mktemp -d)"

cleanup() {
    if [[ "${KEEP_PROBE:-0}" = 1 ]]; then
        echo "KEEP_PROBE=1: retained $PREFIX-* and $NETWORK; temporary files: $PROBE_DIR" >&2
        return
    fi
    docker rm -f "$PREFIX-pbx" "$PREFIX-phone-a" "$PREFIX-phone-b" >/dev/null 2>&1 || true
    docker network rm "$NETWORK" >/dev/null 2>&1 || true
    rm -r "$PROBE_DIR"
}
trap cleanup EXIT

docker rm -f "$PREFIX-pbx" "$PREFIX-phone-a" "$PREFIX-phone-b" >/dev/null 2>&1 || true
docker network rm "$NETWORK" >/dev/null 2>&1 || true
docker network create --subnet 10.109.250.0/24 "$NETWORK" >/dev/null

for node in pbx phone-a phone-b; do
    ip=10.109.250.10
    [[ "$node" = phone-a ]] && ip=10.109.250.11
    [[ "$node" = phone-b ]] && ip=10.109.250.12
    docker run -d --name "$PREFIX-$node" --network "$NETWORK" --ip "$ip" \
        --cap-add NET_ADMIN --cap-add NET_RAW "$IMAGE" >/dev/null
done

docker cp "$LAB_DIR/configs/common/register.xml" "$PREFIX-phone-a:/tmp/register.xml"
docker cp "$LAB_DIR/configs/common/register.xml" "$PREFIX-phone-b:/tmp/register.xml"
sed 's/CALL_DURATION_MS/65000/' "$LAB_DIR/configs/common/phone-a-uac.xml" \
    >"$PROBE_DIR/phone-a-uac.xml"
docker cp "$PROBE_DIR/phone-a-uac.xml" "$PREFIX-phone-a:/tmp/phone-a-uac.xml"
docker cp "$LAB_DIR/configs/common/phone-b-uas.xml" "$PREFIX-phone-b:/tmp/phone-b-uas.xml"

for file in pjsip.conf extensions.conf rtp.conf logger.conf modules.conf; do
    docker cp "$LAB_DIR/probe/asterisk/$file" "$PREFIX-pbx:/etc/asterisk/$file"
done
docker exec "$PREFIX-pbx" asterisk -f >/dev/null 2>&1 &

for _ in $(seq 1 20); do
    docker exec "$PREFIX-pbx" asterisk -rx 'core show version' >/dev/null 2>&1 && break
    sleep 1
done
docker exec "$PREFIX-pbx" asterisk -rx 'core show version'
(docker exec "$PREFIX-pbx" sipp -v 2>&1 || true) | sed -n '2p'

register() {
    local node="$1" user="$2" password="$3" ip="$4"
    docker exec "$PREFIX-$node" sh -c \
        "sed -e 's/AUTH_USER/$user/' -e 's/AUTH_PASS/$password/' /tmp/register.xml >/tmp/register-$user.xml"
    docker exec "$PREFIX-$node" sipp 10.109.250.10:5060 \
        -sf "/tmp/register-$user.xml" -i "$ip" -p 5060 -s "$user" \
        -m 1 -nostdin -nr -trace_msg -message_file "/tmp/$user-messages.log" \
        -trace_err -error_file "/tmp/$user-errors.log" -timeout 10s \
        2>"$PROBE_DIR/$user.err" \
        || {
            cat "$PROBE_DIR/$user.err"
            docker exec "$PREFIX-$node" sh -c "cat /tmp/$user-errors.log /tmp/$user-messages.log 2>/dev/null || true"
            docker exec "$PREFIX-pbx" tail -80 /var/log/asterisk/full || true
            return 1
        }
}

register phone-b 2002 voice-b-2002 10.109.250.12
register phone-a 2001 voice-a-2001 10.109.250.11
docker exec "$PREFIX-pbx" asterisk -rx 'pjsip show contacts'

docker exec -d "$PREFIX-pbx" tcpdump -U -n -i eth0 -w /tmp/probe.pcap \
    'udp port 5060 or udp portrange 10000-10099'
docker exec -d "$PREFIX-phone-b" sipp 10.109.250.10:5060 \
    -sf /tmp/phone-b-uas.xml -i 10.109.250.12 -p 5060 -mi 10.109.250.12 \
    -min_rtp_port 6002 -max_rtp_port 6002 -m 1 -trace_msg -trace_err \
    -nostdin -nr -timeout 75s
sleep 1

/usr/bin/time -f 'call_elapsed=%e call_max_rss_kib=%M' \
    docker exec "$PREFIX-phone-a" sipp 10.109.250.10:5060 \
      -sf /tmp/phone-a-uac.xml -i 10.109.250.11 -p 5060 -mi 10.109.250.11 \
      -min_rtp_port 6000 -max_rtp_port 6000 -s 2002 -m 1 \
      -nostdin -nr -trace_msg -trace_err -timeout 75s

docker exec "$PREFIX-pbx" pkill -INT tcpdump || true
sleep 1
docker cp "$PREFIX-pbx:/tmp/probe.pcap" "$PROBE_DIR/probe.pcap" >/dev/null
python3 "$LAB_DIR/configs/observer/rtp_analyze.py" "$PROBE_DIR/probe.pcap"
docker exec "$PREFIX-pbx" asterisk -rx 'core show channels concise'
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}' \
    "$PREFIX-pbx" "$PREFIX-phone-a" "$PREFIX-phone-b"
