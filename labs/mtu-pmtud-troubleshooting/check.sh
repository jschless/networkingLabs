#!/usr/bin/env bash
# Assert the solved VyOS GRE/PMTUD state and generate fresh mechanism evidence.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "mtu-pmtud-troubleshooting"

container() {
  printf 'clab-%s-%s\n' "$TOPO_NAME" "$1"
}

check_equals() {
  local name="$1" actual="$2" expected="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$name"
  else
    fail "$name" "expected '${expected}', got '${actual}'"
  fi
}

check_image() {
  local node_name="$1" expected="$2" actual
  actual="$(docker inspect --format '{{.Config.Image}}' "$(container "$node_name")" 2>/dev/null)"
  check_equals "$node_name uses exact image $expected" "$actual" "$expected"
}

check_address() {
  local name="$1" node_name="$2" interface="$3" address="$4" output
  output="$(docker exec "$(container "$node_name")" ip -o -4 address show dev "$interface" 2>/dev/null)"
  check_contains "$name" "$output" "[[:space:]]inet ${address//./\\.}([[:space:]]|$)"
}

link_mtu() {
  docker exec "$(container "$1")" ip -o link show dev "$2" 2>/dev/null | \
    sed -nE 's/.*[[:space:]]mtu[[:space:]]+([0-9]+)[[:space:]].*/\1/p' | head -n 1
}

check_mtu() {
  local name="$1" node_name="$2" interface="$3" expected="$4"
  check_equals "$name" "$(link_mtu "$node_name" "$interface")" "$expected"
}

check_config_line() {
  local name="$1" config="$2" regex="$3"
  check_contains "$name" "$config" "^${regex}$"
}

check_tunnel_mtu_config() {
  local node_name="$1" config="$2" lines count
  lines="$(printf '%s\n' "$config" | grep -E '^set interfaces tunnel tun0 mtu ' || true)"
  count="$(printf '%s\n' "$lines" | sed '/^$/d' | wc -l | tr -d ' ')"
  check_equals "$node_name has exactly one configured tun0 MTU" "$count" "1"
  check_contains "$node_name configured tun0 MTU is exactly 1376" "$lines" \
    "^set interfaces tunnel tun0 mtu '?1376'?$"
}

provider_drop_count() {
  docker exec "$(container provider)" iptables -nvx -L OUTPUT 2>/dev/null | \
    awk '/PMTUD_FEEDBACK_BLACKHOLE/{print $1; exit}'
}

check_image host-a ops-lab:local
check_image provider ops-lab:local
check_image host-b ops-lab:local
check_image edge-a vyos:local
check_image edge-b vyos:local

check_contains "edge-a is a live VyOS learned role" \
  "$(vyos_op edge-a 'show version')" 'VyOS'
check_contains "edge-b is a live VyOS learned role" \
  "$(vyos_op edge-b 'show version')" 'VyOS'
for endpoint in host-a provider host-b; do
  check_contains "$endpoint is an incidental Alpine Linux role" \
    "$(docker exec "$(container "$endpoint")" cat /etc/alpine-release 2>/dev/null)" \
    '^[0-9]+\.[0-9]+'
done

check_address "host-a has exact site address" host-a eth1 192.168.1.10/24
check_address "edge-a eth1 has exact LAN address" edge-a eth1 192.168.1.1/24
check_address "edge-a eth2 has exact WAN address" edge-a eth2 203.0.113.1/30
check_address "edge-a tun0 has exact overlay address" edge-a tun0 172.16.0.1/30
check_address "provider eth1 has exact west address" provider eth1 203.0.113.2/30
check_address "provider eth2 has exact east address" provider eth2 203.0.113.5/30
check_address "edge-b eth2 has exact WAN address" edge-b eth2 203.0.113.6/30
check_address "edge-b eth1 has exact LAN address" edge-b eth1 192.168.2.1/24
check_address "edge-b tun0 has exact overlay address" edge-b tun0 172.16.0.2/30
check_address "host-b has exact site address" host-b eth1 192.168.2.10/24

check_mtu "host-a physical MTU is 1500" host-a eth1 1500
check_mtu "edge-a LAN physical MTU is 1500" edge-a eth1 1500
check_mtu "edge-a WAN physical MTU is 1500" edge-a eth2 1500
check_mtu "provider west physical MTU is 1400" provider eth1 1400
check_mtu "provider east physical MTU is 1400" provider eth2 1400
check_mtu "edge-b WAN physical MTU is 1500" edge-b eth2 1500
check_mtu "edge-b LAN physical MTU is 1500" edge-b eth1 1500
check_mtu "host-b physical MTU is 1500" host-b eth1 1500

edge_a_config="$(vyos_op edge-a 'show configuration commands')"
edge_b_config="$(vyos_op edge-b 'show configuration commands')"

check_config_line "edge-a GRE address is exact" "$edge_a_config" \
  "set interfaces tunnel tun0 address '?172\\.16\\.0\\.1/30'?"
check_config_line "edge-a uses native GRE encapsulation" "$edge_a_config" \
  "set interfaces tunnel tun0 encapsulation '?gre'?"
check_config_line "edge-a GRE remote is exact" "$edge_a_config" \
  "set interfaces tunnel tun0 remote '?203\\.0\\.113\\.6'?"
check_config_line "edge-a GRE source is exact" "$edge_a_config" \
  "set interfaces tunnel tun0 source-address '?203\\.0\\.113\\.1'?"
check_config_line "edge-a remote-LAN route is exact" "$edge_a_config" \
  "set protocols static route '?192\\.168\\.2\\.0/24'? next-hop '?172\\.16\\.0\\.2'?"
check_config_line "edge-a transport route is exact" "$edge_a_config" \
  "set protocols static route '?203\\.0\\.113\\.4/30'? next-hop '?203\\.0\\.113\\.2'?"

check_config_line "edge-b GRE address is exact" "$edge_b_config" \
  "set interfaces tunnel tun0 address '?172\\.16\\.0\\.2/30'?"
check_config_line "edge-b uses native GRE encapsulation" "$edge_b_config" \
  "set interfaces tunnel tun0 encapsulation '?gre'?"
check_config_line "edge-b GRE remote is exact" "$edge_b_config" \
  "set interfaces tunnel tun0 remote '?203\\.0\\.113\\.1'?"
check_config_line "edge-b GRE source is exact" "$edge_b_config" \
  "set interfaces tunnel tun0 source-address '?203\\.0\\.113\\.6'?"
check_config_line "edge-b remote-LAN route is exact" "$edge_b_config" \
  "set protocols static route '?192\\.168\\.1\\.0/24'? next-hop '?172\\.16\\.0\\.1'?"
check_config_line "edge-b transport route is exact" "$edge_b_config" \
  "set protocols static route '?203\\.0\\.113\\.0/30'? next-hop '?203\\.0\\.113\\.5'?"

check_tunnel_mtu_config edge-a "$edge_a_config"
check_tunnel_mtu_config edge-b "$edge_b_config"

edge_a_tun="$(docker exec "$(container edge-a)" ip -o link show dev tun0 2>/dev/null)"
edge_b_tun="$(docker exec "$(container edge-b)" ip -o link show dev tun0 2>/dev/null)"
check_contains "edge-a tun0 is operationally UP" "$edge_a_tun" '<[^>]*UP[^>]*>'
check_contains "edge-b tun0 is operationally UP" "$edge_b_tun" '<[^>]*UP[^>]*>'
check_mtu "edge-a tun0 operational MTU is 1376" edge-a tun0 1376
check_mtu "edge-b tun0 operational MTU is 1376" edge-b tun0 1376

edge_a_routes="$(docker exec "$(container edge-a)" ip -4 route show 2>/dev/null)"
edge_b_routes="$(docker exec "$(container edge-b)" ip -4 route show 2>/dev/null)"
check_contains "edge-a installed exact remote-LAN path" "$edge_a_routes" \
  '^192\.168\.2\.0/24 .*via 172\.16\.0\.2 dev tun0'
check_contains "edge-a installed exact remote-WAN path" "$edge_a_routes" \
  '^203\.0\.113\.4/30 .*via 203\.0\.113\.2 dev eth2'
check_contains "edge-b installed exact remote-LAN path" "$edge_b_routes" \
  '^192\.168\.1\.0/24 .*via 172\.16\.0\.1 dev tun0'
check_contains "edge-b installed exact remote-WAN path" "$edge_b_routes" \
  '^203\.0\.113\.0/30 .*via 203\.0\.113\.5 dev eth2'

check_contains "host-a default route points to edge-a" \
  "$(docker exec "$(container host-a)" ip -4 route show default 2>/dev/null)" \
  '^default via 192\.168\.1\.1 dev eth1'
check_contains "host-b default route points to edge-b" \
  "$(docker exec "$(container host-b)" ip -4 route show default 2>/dev/null)" \
  '^default via 192\.168\.2\.1 dev eth1'
check_equals "provider IPv4 forwarding is enabled" \
  "$(docker exec "$(container provider)" sysctl -n net.ipv4.ip_forward 2>/dev/null)" "1"

if docker exec "$(container provider)" iptables -C OUTPUT -p icmp \
  --icmp-type fragmentation-needed -m comment \
  --comment PMTUD_FEEDBACK_BLACKHOLE -j DROP 2>/dev/null; then
  pass "provider retains the required ICMP type 3/code 4 drop rule"
else
  fail "provider retains the required ICMP type 3/code 4 drop rule" \
    "exact OUTPUT rule is absent"
fi
provider_rule_count="$(docker exec "$(container provider)" iptables-save 2>/dev/null | \
  grep -c 'PMTUD_FEEDBACK_BLACKHOLE' || true)"
check_equals "provider has exactly one feedback-drop rule" "$provider_rule_count" "1"

host_a_services="$(docker exec "$(container host-a)" ss -H -lntup 2>/dev/null)"
host_b_services="$(docker exec "$(container host-b)" ss -H -lntup 2>/dev/null)"
check_contains "host-a UDP/9999 echo listener is healthy" "$host_a_services" \
  '0\.0\.0\.0:9999'
check_contains "host-b UDP/9999 echo listener is healthy" "$host_b_services" \
  '0\.0\.0\.0:9999'
check_contains "host-b TCP/8080 threaded HTTP listener is healthy" "$host_b_services" \
  '0\.0\.0\.0:8080'
check_equals "host-a has exactly one shared service process" \
  "$(docker exec "$(container host-a)" pgrep -fc '^python3 /services.py$' 2>/dev/null || true)" "1"
check_equals "host-b has exactly one shared service process" \
  "$(docker exec "$(container host-b)" pgrep -fc '^python3 /services.py --http$' 2>/dev/null || true)" "1"

check_ping_linux "host-a -> host-b small reachability" host-a 192.168.2.10
check_ping_linux "host-b -> host-a small reachability" host-b 192.168.1.10

docker exec "$(container host-a)" ip route flush cache >/dev/null 2>&1 || true
docker exec "$(container host-b)" ip route flush cache >/dev/null 2>&1 || true

provider_before="$(provider_drop_count)"
if [[ "$provider_before" =~ ^[0-9]+$ ]]; then
  pass "provider drop counter is readable before final probes"
else
  fail "provider drop counter is readable before final probes" \
    "counter value '${provider_before}' is not numeric"
fi

probe_ab="$(docker exec "$(container host-a)" /df-probe.py 1348 192.168.2.10 2>&1)"
probe_ab_status=$?
check_equals "A-to-B 1348 DF probe exits successfully" "$probe_ab_status" "0"
check_contains "A-to-B 1348 DF probe returns exact acknowledgement" "$probe_ab" '^ack:1348$'

probe_ba="$(docker exec "$(container host-b)" /df-probe.py 1348 192.168.1.10 2>&1)"
probe_ba_status=$?
check_equals "B-to-A 1348 DF probe exits successfully" "$probe_ba_status" "0"
check_contains "B-to-A 1348 DF probe returns exact acknowledgement" "$probe_ba" '^ack:1348$'

capture_file="$(mktemp -t mtu-pmtud-check-icmp.XXXXXX)"
docker exec "$(container host-a)" timeout 6 tcpdump -lnni eth1 -vv -c 1 \
  'icmp[0] == 3 and icmp[1] == 4' >"$capture_file" 2>&1 &
capture_pid=$!
sleep 0.4

probe_1349="$(docker exec "$(container host-a)" /df-probe.py 1349 192.168.2.10 2>&1)"
probe_1349_status=$?
for _attempt in {1..30}; do
  if grep -q 'mtu 1376' "$capture_file" 2>/dev/null; then
    break
  fi
  sleep 0.1
done
wait "$capture_pid" 2>/dev/null || true
capture_out="$(cat "$capture_file")"
rm -f "$capture_file"

check_equals "A-to-B 1349 DF probe exits with EMSGSIZE status" \
  "$probe_1349_status" "2"
check_contains "A-to-B 1349 DF probe reports stable EMSGSIZE evidence" \
  "$probe_1349" '^EMSGSIZE payload=1349 destination=192\.168\.2\.10$'
check_contains "fresh host capture proves ICMP type 3/code 4 MTU 1376" \
  "$capture_out" 'ICMP.*(need to frag|unreachable).*mtu 1376'

http_out="$(docker exec "$(container host-a)" timeout 10 python3 -c \
  "import urllib.request; body=urllib.request.urlopen('http://192.168.2.10:8080', timeout=8).read(); print(f'bytes:{len(body)}')" 2>&1)"
http_status=$?
check_equals "bounded 256 KiB HTTP fetch exits successfully" "$http_status" "0"
check_contains "HTTP service returns exactly 262144 bytes" "$http_out" '^bytes:262144$'

provider_after="$(provider_drop_count)"
check_equals "provider feedback-drop counter stays unchanged during final probes" \
  "$provider_after" "$provider_before"

# BusyBox `timeout` can remain visible briefly after its captured child exits.
# Give the bounded wrapper a chance to reap before enforcing process cleanup.
for _attempt in {1..50}; do
  capture_wrapper="$(docker exec "$(container host-a)" sh -c \
    "ps -eo args | grep -E '[t]imeout 6 tcpdump -lnni eth1|[t]cpdump -lnni eth1'" \
    2>/dev/null || true)"
  [[ -z "$capture_wrapper" ]] && break
  sleep 0.1
done

for node_name in host-a provider host-b; do
  leaked="$(docker exec "$(container "$node_name")" sh -c \
    "ps -eo args | grep -E '[t]cpdump|[d]f-probe\.py'" 2>/dev/null || true)"
  check_equals "$node_name has no leaked capture or probe process" "$leaked" ""
done
if [[ ! -e "$capture_file" ]]; then
  pass "temporary checker capture file was removed"
else
  fail "temporary checker capture file was removed" "$capture_file remains"
fi

summary
