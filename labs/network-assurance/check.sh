#!/usr/bin/env bash
# Assert every assurance plane and generate fresh, correlated evidence.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "network-assurance"

# Initialize capture state before installing traps so cleanup is safe even if
# the script is interrupted before either bounded capture starts.
span_capture=""
flow_datagram_capture=""
span_pid=""
flow_capture_pid=""
capture_run_id="network-assurance-check-$$"
span_container_pid_file="/run/${capture_run_id}-span.pid"
flow_container_pid_file="/run/${capture_run_id}-netflow.pid"
span_expected_cmdline='timeout 12 tcpdump -lnni eth1 -c 4 icmp and (host 10.1.0.2 or host 10.2.0.2)'
flow_expected_cmdline='timeout 15 tcpdump -lnni eth2 -c 1 udp dst port 2055'

stop_container_capture() {
  local node_name="$1" pid_file="$2" expected_cmdline="$3"

  docker exec "clab-${TOPO_NAME}-${node_name}" sh -c '
    pid_file=$1
    expected_cmdline=$2
    [ -r "$pid_file" ] || exit 0

    capture_pid=$(sed -n "1p" "$pid_file")
    case "$capture_pid" in
      ""|*[!0-9]*) rm -f -- "$pid_file"; exit 0 ;;
    esac

    command_matches() {
      [ -r "/proc/$capture_pid/cmdline" ] || return 1
      actual_cmdline=$(tr "\000" " " <"/proc/$capture_pid/cmdline")
      actual_cmdline=${actual_cmdline% }
      [ "$actual_cmdline" = "$expected_cmdline" ]
    }

    if command_matches; then
      kill "$capture_pid" 2>/dev/null || true
      attempt=0
      while [ "$attempt" -lt 50 ] && command_matches; do
        attempt=$((attempt + 1))
        sleep 0.1
      done
      if command_matches; then
        kill -KILL "$capture_pid" 2>/dev/null || true
      fi
    fi
    rm -f -- "$pid_file"
  ' sh "$pid_file" "$expected_cmdline" >/dev/null 2>&1 || true
}

stop_host_capture() {
  local capture_pid="$1"

  if [[ -n "$capture_pid" ]] && kill -0 "$capture_pid" 2>/dev/null; then
    kill "$capture_pid" 2>/dev/null || true
  fi
  if [[ -n "$capture_pid" ]]; then
    wait "$capture_pid" 2>/dev/null || true
  fi
}

cleanup_captures() {
  stop_container_capture sensor "$span_container_pid_file" \
    "$span_expected_cmdline"
  stop_host_capture "$span_pid"
  # Recheck after reaping the client to close the narrow race where the exec
  # starts and publishes its container PID while the first check is running.
  stop_container_capture sensor "$span_container_pid_file" \
    "$span_expected_cmdline"
  stop_container_capture management "$flow_container_pid_file" \
    "$flow_expected_cmdline"
  stop_host_capture "$flow_capture_pid"
  stop_container_capture management "$flow_container_pid_file" \
    "$flow_expected_cmdline"

  span_pid=""
  flow_capture_pid=""
  [[ -n "$span_capture" ]] && rm -f -- "$span_capture"
  [[ -n "$flow_datagram_capture" ]] && rm -f -- "$flow_datagram_capture"
}

trap cleanup_captures EXIT
trap 'cleanup_captures; exit 130' INT
trap 'cleanup_captures; exit 143' TERM

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

check_number_at_least() {
  local name="$1" actual="$2" minimum="$3"
  if [[ "$actual" =~ ^[0-9]+$ ]] && (( actual >= minimum )); then
    pass "$name"
  else
    fail "$name" "expected a number >= ${minimum}, got '${actual}'"
  fi
}

check_image() {
  local node_name="$1" expected="$2" actual
  actual="$(docker inspect --format '{{.Config.Image}}' "$(container "$node_name")" 2>/dev/null)"
  check_equals "$node_name uses exact image $expected" "$actual" "$expected"
}

active_process_count() {
  local node_name="$1" process_name="$2"
  docker exec "$(container "$node_name")" ps -eo stat=,comm= 2>/dev/null | awk \
    -v process_name="$process_name" \
    '$2 == process_name && $1 !~ /^Z/ { count++ } END { print count + 0 }'
}

check_address() {
  local name="$1" node_name="$2" interface="$3" address="$4" output
  output="$(docker exec "$(container "$node_name")" ip -o -4 address show dev "$interface" 2>/dev/null)"
  check_contains "$name" "$output" "[[:space:]]inet ${address//./\\.}([[:space:]]|$)"
}

running_nodes="$(docker ps --format '{{.Names}}' | grep -Ec \
  '^clab-network-assurance-(router|client|server|management|sensor)$' || true)"
check_equals "all five expected lab containers are running" "$running_nodes" "5"

check_image router ceos:4.35.2F
check_image client ops-lab:local
check_image server ops-lab:local
check_image management assurance-lab:local
check_image sensor assurance-lab:local

check_contains "router is native EOS 4.35.2F" \
  "$(eos router 'show version')" 'Software image version: 4\.35\.2F'

router_config="$(eos router 'show running-config')"
check_contains "router Ethernet1 owns the client address" "$router_config" \
  'ip address 10\.1\.0\.1/24'
check_contains "router Ethernet2 owns the server address" "$router_config" \
  'ip address 10\.2\.0\.1/24'
check_contains "router Ethernet3 owns the management address" "$router_config" \
  'ip address 172\.16\.0\.1/24'
check_contains "router has the exact read-only SNMP community" "$router_config" \
  '^snmp-server community ASSURANCE ro$'
check_contains "router requires privacy for the SNMPv3 group" "$router_config" \
  '^snmp-server group assurance v3 priv$'
check_contains "router has the expected SNMPv3 observer" "$router_config" \
  '^snmp-server user observer assurance v3 .+ auth sha .+ priv aes .+'
check_contains "router sends syslog to management" "$router_config" \
  '^logging host 172\.16\.0\.2$'
check_contains "router sources syslog from Ethernet3" "$router_config" \
  '^logging local-interface Ethernet3$'

check_address "client has its exact data address" client eth1 10.1.0.2/24
check_address "server has its exact data address" server eth1 10.2.0.2/24
check_address "management has its router-facing address" management eth1 172.16.0.2/24
check_address "management has its collector address" management eth2 172.16.1.1/30
check_address "sensor has its export-path address" sensor eth2 172.16.1.2/30
check_equals "sensor capture interface is unnumbered" \
  "$(docker exec "$(container sensor)" ip -o -4 address show dev eth1 2>/dev/null)" ""
check_contains "sensor capture interface is promiscuous" \
  "$(docker exec "$(container sensor)" ip -o link show dev eth1 2>/dev/null)" \
  '<[^>]*PROMISC[^>]*>'
check_contains "client default route points to router" \
  "$(docker exec "$(container client)" ip -4 route show default 2>/dev/null)" \
  '^default via 10\.1\.0\.1 dev eth1'
check_contains "server default route points to router" \
  "$(docker exec "$(container server)" ip -4 route show default 2>/dev/null)" \
  '^default via 10\.2\.0\.1 dev eth1'

interface_status="$(eos router 'show interfaces status')"
for interface in Et1 Et2 Et3 Et4; do
  check_contains "router $interface is connected" "$interface_status" \
    "^${interface}[[:space:]].*connected"
done

check_ping_linux "client reaches server through EOS" client 10.2.0.2
check_ping_linux "management reaches EOS telemetry address" management 172.16.0.1
check_ping_linux "sensor reaches the NetFlow collector" sensor 172.16.1.1

snmp_v2_name="$(docker exec "$(container management)" \
  snmpget -v2c -c ASSURANCE -On 172.16.0.1 .1.3.6.1.2.1.1.5.0 2>&1)"
check_contains "SNMPv2c numeric sysName poll succeeds" "$snmp_v2_name" \
  'STRING: "assurance-router"'

snmp_v3_name="$(docker exec "$(container management)" \
  snmpget -v3 -u observer -l authPriv -a SHA -A AssuranceAuth123 \
  -x AES -X AssurancePriv123 -On 172.16.0.1 .1.3.6.1.2.1.1.5.0 2>&1)"
check_contains "SNMPv3 authPriv numeric sysName poll succeeds" "$snmp_v3_name" \
  'STRING: "assurance-router"'

if_descr="$(docker exec "$(container management)" \
  snmpwalk -v2c -c ASSURANCE -On 172.16.0.1 .1.3.6.1.2.1.2.2.1.2 2>&1)"
check_contains "SNMP exposes Ethernet1 at ifIndex 1" "$if_descr" \
  '^\.1\.3\.6\.1\.2\.1\.2\.2\.1\.2\.1 = STRING: "Ethernet1"'
check_contains "SNMP exposes Ethernet2 at ifIndex 2" "$if_descr" \
  '^\.1\.3\.6\.1\.2\.1\.2\.2\.1\.2\.2 = STRING: "Ethernet2"'
check_contains "SNMP reports Ethernet2 operationally up" \
  "$(docker exec "$(container management)" snmpget -v2c -c ASSURANCE -On \
    172.16.0.1 .1.3.6.1.2.1.2.2.1.8.2 2>&1)" 'INTEGER: 1$'

check_equals "rsyslog receiver process is healthy" \
  "$(active_process_count management rsyslogd)" "1"
check_contains "rsyslog owns UDP/514" \
  "$(docker exec "$(container management)" ss -H -lunp 2>/dev/null)" \
  '0\.0\.0\.0:514.*rsyslogd'

syslog_marker="ASSURANCE_CHECK_$(date +%s)_$$"
eos router "send log level informational message ${syslog_marker}" >/dev/null
fresh_syslog=""
for _attempt in {1..50}; do
  fresh_syslog="$(docker exec "$(container management)" \
    sh -c "grep '$syslog_marker' /var/log/remote/router.log 2>/dev/null" || true)"
  [[ -n "$fresh_syslog" ]] && break
  sleep 0.1
done
check_contains "fresh native EOS syslog reaches management" "$fresh_syslog" "$syslog_marker"

monitor_output="$(eos router 'show monitor session ASSURANCE')"
check_contains "native monitor session has Ethernet1 as source" "$monitor_output" \
  '^Both Interfaces:[[:space:]]+Et1$'
check_contains "native monitor session has Ethernet4 as destination" "$monitor_output" \
  '^[[:space:]]*Et4[[:space:]]*:[[:space:]]*active'
check_contains "native monitor session is active" "$monitor_output" \
  '^[[:space:]]*Et4[[:space:]]*:[[:space:]]*active'

span_capture="$(mktemp -t network-assurance-span.XXXXXX)"
docker exec "$(container sensor)" sh -c '
  printf "%s\n" "$$" >"$1"
  exec timeout 12 tcpdump -lnni eth1 -c 4 \
    "icmp and (host 10.1.0.2 or host 10.2.0.2)"
' sh "$span_container_pid_file" >"$span_capture" 2>&1 &
span_pid=$!
sleep 0.5
docker exec "$(container client)" ping -q -c 4 -W 2 10.2.0.2 >/dev/null 2>&1 || true
wait "$span_pid" 2>/dev/null || true
docker exec "$(container sensor)" rm -f -- "$span_container_pid_file" \
  >/dev/null 2>&1 || true
span_pid=""
span_output="$(cat "$span_capture")"
check_contains "fresh SPAN capture sees an echo request" "$span_output" \
  '10\.1\.0\.2 > 10\.2\.0\.2: ICMP echo request'
check_contains "fresh SPAN capture sees the matching echo reply" "$span_output" \
  '10\.2\.0\.2 > 10\.1\.0\.2: ICMP echo reply'
rm -f "$span_capture"

check_equals "nfcapd collector process is healthy" \
  "$(active_process_count management nfcapd)" "1"
check_contains "nfcapd owns UDP/2055" \
  "$(docker exec "$(container management)" ss -H -lunp 2>/dev/null)" \
  '0\.0\.0\.0:2055.*nfcapd'
check_equals "softflowd sensor process is healthy" \
  "$(active_process_count sensor softflowd)" "1"
check_contains "softflowd uses the exact SPAN and collector paths" \
  "$(docker exec "$(container sensor)" pgrep -ax softflowd 2>/dev/null)" \
  'softflowd -d -i eth1 -n 172\.16\.1\.1:2055 -v 9'

flow_control_status=1
docker exec "$(container sensor)" softflowctl -c /run/softflowd.ctl statistics \
  >/dev/null 2>&1 && flow_control_status=0
check_equals "softflowd control socket answers" "$flow_control_status" "0"

# Discard stale records before producing a fresh, high-volume flow. Leave the
# collector running: after one rotation it closes the now-unlinked active file
# and creates a clean file. This avoids process churn and keeps repeated runs
# deterministic. A large burst is intentional because small bursts can remain
# in libpcap batching in this environment.
docker exec "$(container sensor)" softflowctl -c /run/softflowd.ctl expire-all \
  >/dev/null 2>&1 || true
docker exec "$(container management)" sh -c \
  'rm -f /var/log/netflow/nfcapd.*' >/dev/null 2>&1
sleep 6

ethernet1_octets_before="$(docker exec "$(container management)" \
  snmpget -v2c -c ASSURANCE -Oqv 172.16.0.1 \
  .1.3.6.1.2.1.31.1.1.1.6.1 2>/dev/null)"

flow_datagram_capture="$(mktemp -t network-assurance-netflow.XXXXXX)"
docker exec "$(container management)" sh -c '
  printf "%s\n" "$$" >"$1"
  exec timeout 15 tcpdump -lnni eth2 -c 1 "udp dst port 2055"
' sh "$flow_container_pid_file" >"$flow_datagram_capture" 2>&1 &
flow_capture_pid=$!
sleep 0.5
docker exec "$(container client)" ping -q -c 2000 -i 0.001 -s 1400 \
  10.2.0.2 >/dev/null 2>&1 || true
ethernet1_octets_after="$(docker exec "$(container management)" \
  snmpget -v2c -c ASSURANCE -Oqv 172.16.0.1 \
  .1.3.6.1.2.1.31.1.1.1.6.1 2>/dev/null)"
if [[ "$ethernet1_octets_before" =~ ^[0-9]+$ \
  && "$ethernet1_octets_after" =~ ^[0-9]+$ ]]; then
  ethernet1_octets_delta=$((ethernet1_octets_after - ethernet1_octets_before))
else
  ethernet1_octets_delta="unreadable (${ethernet1_octets_before} -> ${ethernet1_octets_after})"
fi
check_number_at_least "fresh burst increases Ethernet1 ifHCInOctets by at least 2 MB" \
  "$ethernet1_octets_delta" 2000000
docker exec "$(container sensor)" softflowctl -c /run/softflowd.ctl expire-all \
  >/dev/null 2>&1 || true
wait "$flow_capture_pid" 2>/dev/null || true
docker exec "$(container management)" rm -f -- "$flow_container_pid_file" \
  >/dev/null 2>&1 || true
flow_capture_pid=""
sleep 7

flow_datagram_output="$(cat "$flow_datagram_capture")"
rm -f "$flow_datagram_capture"
check_contains "fresh NetFlow export datagram reaches management" \
  "$flow_datagram_output" '172\.16\.1\.2\.[0-9]+ > 172\.16\.1\.1\.2055: UDP'

flow_records="$(docker exec "$(container management)" nfdump \
  -N -R /var/log/netflow -o 'fmt:%sa %da %pkt %byt' \
  'proto icmp and (host 10.1.0.2 or host 10.2.0.2)' 2>&1 || true)"
check_contains "fresh NetFlow records include client to server" "$flow_records" \
  '10\.1\.0\.2[[:space:]]+10\.2\.0\.2'
check_contains "fresh NetFlow records include server to client" "$flow_records" \
  '10\.2\.0\.2[[:space:]]+10\.1\.0\.2'

forward_packets="$(printf '%s\n' "$flow_records" | awk \
  '$1 == "10.1.0.2" && $2 == "10.2.0.2" { total += $3 } END { print total + 0 }')"
reverse_packets="$(printf '%s\n' "$flow_records" | awk \
  '$1 == "10.2.0.2" && $2 == "10.1.0.2" { total += $3 } END { print total + 0 }')"
forward_bytes="$(printf '%s\n' "$flow_records" | awk \
  '$1 == "10.1.0.2" && $2 == "10.2.0.2" { total += $4 } END { print total + 0 }')"
reverse_bytes="$(printf '%s\n' "$flow_records" | awk \
  '$1 == "10.2.0.2" && $2 == "10.1.0.2" { total += $4 } END { print total + 0 }')"
check_number_at_least "forward NetFlow total has at least 1000 packets" \
  "$forward_packets" 1000
check_number_at_least "reverse NetFlow total has at least 1000 packets" \
  "$reverse_packets" 1000
check_number_at_least "forward NetFlow total has at least 1 MB" \
  "$forward_bytes" 1000000
check_number_at_least "reverse NetFlow total has at least 1 MB" \
  "$reverse_bytes" 1000000

for node_name in sensor management; do
  leaked="$(docker exec "$(container "$node_name")" sh -c \
    "ps -eo args | grep -E '[t]imeout (12|15) tcpdump'" 2>/dev/null || true)"
  check_equals "$node_name has no leaked bounded capture" "$leaked" ""
done
if [[ ! -e "$span_capture" && ! -e "$flow_datagram_capture" ]]; then
  pass "checker temporary capture files were removed"
else
  fail "checker temporary capture files were removed" "one or more capture files remain"
fi

summary
