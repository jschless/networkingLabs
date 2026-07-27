#!/usr/bin/env bash
set -euo pipefail

P="clab-enterprise-voice-sip-qos"

register() {
    local node="$1" user="$2" password="$3" target="$4" ip="$5"
    docker exec "$P-$node" sh -c \
      "sed -e 's/AUTH_USER/$user/' -e 's/AUTH_PASS/$password/' \
       /opt/voice/register.xml >/tmp/register-$user.xml"
    docker exec "$P-$node" sipp "$target:5060" \
      -sf "/tmp/register-$user.xml" -i "$ip" -p 5060 -s "$user" \
      -m 1 -nostdin -nr -trace_err -error_file "/tmp/register-$user-errors.log" \
      -timeout 10s >/tmp/"$user"-register-screen.log 2>&1
}

docker exec "$P-phone-a" pkill sipp >/dev/null 2>&1 || true
docker exec "$P-phone-b" pkill sipp >/dev/null 2>&1 || true
PHONE_A_IP="$(docker exec "$P-phone-a" ip -4 -o addr show dev eth1 | awk '{print $4}' | cut -d/ -f1)"
[[ -n "$PHONE_A_IP" ]] || { echo "phone-a has no voice DHCP address" >&2; exit 1; }
register phone-b 2002 voice-b-2002 192.0.2.110 10.109.40.20
register phone-a 2001 voice-a-2001 10.109.30.10 "$PHONE_A_IP"
printf 'REGISTERED\n' | docker exec -i "$P-phone-a" sh -c 'cat >/run/voice/state'
printf 'REGISTERED\n' | docker exec -i "$P-phone-b" sh -c 'cat >/run/voice/state'
docker exec "$P-pbx" asterisk -rx 'pjsip show contacts'
