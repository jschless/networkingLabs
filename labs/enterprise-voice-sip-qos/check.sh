#!/usr/bin/env bash
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LAB_DIR="$REPO_ROOT/labs/enterprise-voice-sip-qos"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "enterprise-voice-sip-qos"
P="clab-${TOPO_NAME}"

check_contains "voice services declare healthy" \
  "$(node dns-ntp 'cat /run/voice/services-state')" '^HEALTHY$'
check_contains "voice DHCP lease is in VLAN 20" \
  "$(node phone-a 'ip -4 -o addr show dev eth1')" '10\.109\.20\.'
check_contains "data DHCP lease is in VLAN 10" \
  "$(node traffic-gen 'ip -4 -o addr show dev eth1')" '10\.109\.10\.'
check_contains "PBX A record resolves" \
  "$(node phone-a 'dig +short pbx.voice.lab @10.109.30.53')" '^10\.109\.30\.10$'
check_contains "SIP SRV record resolves" \
  "$(node phone-a 'dig +short SRV _sip._udp.voice.lab @10.109.30.53')" '5060 pbx\.voice\.lab\.'

NTP_OUT="$(docker exec "$P-phone-a" sh -c \
  "printf 'server 10.109.30.53 iburst\\n' >/tmp/chrony-check.conf; chronyd -Q -t 5 -f /tmp/chrony-check.conf" 2>&1 || true)"
check_contains "NTP query reaches the voice time source" "$NTP_OUT" 'System clock (wrong|was stepped)'

CONTACTS="$(node pbx "asterisk -rx 'pjsip show contacts'")"
check_contains "phone-a is registered" "$CONTACTS" '2001/sip:2001@10\.109\.20\.'
check_contains "phone-b is registered through the edge" "$CONTACTS" '2002/sip:2002@10\.109\.40\.20'

node traffic-gen 'ip addr add 10.109.20.250/24 dev eth1 2>/dev/null || true'
if node traffic-gen 'ping -I 10.109.20.250 -c2 -W1 10.109.20.1' >/dev/null; then
  fail "data port cannot impersonate the voice VLAN" "static voice source unexpectedly reached the voice SVI"
else
  pass "data port cannot impersonate the voice VLAN"
fi
node traffic-gen 'ip addr del 10.109.20.250/24 dev eth1 2>/dev/null || true'

PBX_GUARD="$(node pbx 'nft list chain inet pbx_guard input' || true)"
check_contains "data-to-SIP policy is explicitly denied" "$PBX_GUARD" \
  'ip saddr 10\.109\.10\.0/24 udp dport 5060.*drop'
check_contains "PBX management ports are restricted" "$PBX_GUARD" \
  'tcp dport \{ 5038, 8088 \}.*drop'

BEFORE="$(node wan-edge "nft list counter ip voice_edge untrusted_ef | awk '/packets/{print \$2}'")"
node traffic-gen 'ping -Q 0xb8 -c2 -W1 10.109.40.20' >/dev/null 2>&1 || true
AFTER="$(node wan-edge "nft list counter ip voice_edge untrusted_ef | awk '/packets/{print \$2}'")"
if [[ "$BEFORE" =~ ^[0-9]+$ && "$AFTER" =~ ^[0-9]+$ && "$AFTER" -gt "$BEFORE" ]]; then
  pass "untrusted EF is counted and remarked"
else
  fail "untrusted EF is counted and remarked" "counter did not increase ($BEFORE -> $AFTER)"
fi

node traffic-gen \
  'rm -f /tmp/check-iperf.json; (iperf3 -c 10.109.40.20 -u -b 8M -l 1200 -t 10 -S 0xb8 -J >/tmp/check-iperf.json 2>/tmp/check-iperf.err) &' \
  >/dev/null
if "$LAB_DIR/run-call.sh" 8 check >/tmp/enterprise-voice-check-call.log 2>&1; then
  pass "SIP call establishes and terminates cleanly"
else
  fail "SIP call establishes and terminates cleanly" "SIPp scenario failed"
fi
for _ in $(seq 1 30); do
  node traffic-gen 'test -s /tmp/check-iperf.json' && break
  sleep 1
done

RTP_JSON="$(node observer 'cat /captures/check-phone-b.json' 2>/dev/null || echo '{}')"
STREAMS="$(jq 'length' <<<"$RTP_JSON" 2>/dev/null || echo 0)"
if [[ "$STREAMS" -eq 2 ]]; then
  pass "remote capture contains bidirectional RTP"
else
  fail "remote capture contains bidirectional RTP" "expected 2 streams, observed $STREAMS"
fi
check_contains "remote endpoint targets the public media address" \
  "$(jq -r 'keys[]' <<<"$RTP_JSON" 2>/dev/null)" \
  '10\.109\.40\.20:6002>192\.0\.2\.110:10[0-9][0-9][0-9]'
RTP_BAD="$(jq '[.[] | select(.packets < 300 or .loss_pct > 1 or .jitter_ms > 10)] | length' <<<"$RTP_JSON" 2>/dev/null || echo 1)"
if [[ "$RTP_BAD" -eq 0 && "$STREAMS" -eq 2 ]]; then
  pass "RTP stays below 1% loss and 10 ms jitter under congestion"
else
  fail "RTP stays below 1% loss and 10 ms jitter under congestion" "one or more streams missed threshold"
fi
PBX_JSON="$(node observer 'cat /captures/check-pbx.json' 2>/dev/null || echo '{}')"
PBX_STREAMS="$(jq 'length' <<<"$PBX_JSON" 2>/dev/null || echo 0)"
if [[ "$PBX_STREAMS" -eq 4 ]]; then
  pass "PBX capture contains both directions on both call legs"
else
  fail "PBX capture contains both directions on both call legs" "expected 4 streams, observed $PBX_STREAMS"
fi

IPERF_JSON="$(node traffic-gen 'cat /tmp/check-iperf.json' 2>/dev/null || echo '{}')"
BE_LOSS="$(jq -r '.end.sum.lost_percent // 0' <<<"$IPERF_JSON" 2>/dev/null || echo 0)"
if awk "BEGIN {exit !($BE_LOSS > 20)}"; then
  pass "best effort degrades predictably under the 8 Mb/s offer"
else
  fail "best effort degrades predictably under the 8 Mb/s offer" "observed loss ${BE_LOSS}% was not above 20%"
fi

TC_VOICE="$(node wan-edge "tc -s class show dev eth2 classid 1:10 | awk '/Sent/{print \$4}'")"
if [[ "$TC_VOICE" =~ ^[0-9]+$ && "$TC_VOICE" -gt 300 ]]; then
  pass "EF/CS3 traffic traverses the bounded priority class"
else
  fail "EF/CS3 traffic traverses the bounded priority class" "voice class packet count was $TC_VOICE"
fi
check_contains "remote media uses scoped stateful NAT" \
  "$(node wan-edge 'conntrack -L -p udp 2>/dev/null')" \
  'src=10\.109\.40\.20 dst=192\.0\.2\.110.*dport=10[0-9][0-9][0-9]'

summary
