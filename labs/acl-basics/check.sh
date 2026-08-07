#!/usr/bin/env bash
# Assert the solved cEOS transit-ACL policy and generate fresh counter evidence.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "acl-basics"

tcp_open() {
  local node_name="$1" address="$2" port="$3"
  docker exec "clab-${TOPO_NAME}-${node_name}" \
    nc -zw3 "$address" "$port" &>/dev/null
}

probe_allowed() {
  local name="$1" node_name="$2" address="$3" port="$4"
  if tcp_open "$node_name" "$address" "$port"; then
    pass "$name"
  else
    fail "$name" "TCP/${port} is not reachable from ${node_name}"
  fi
}

probe_denied() {
  local name="$1" node_name="$2" address="$3" port="$4"
  if ! tcp_open "$node_name" "$address" "$port"; then
    pass "$name"
  else
    fail "$name" "TCP/${port} is unexpectedly reachable from ${node_name}"
  fi
}

acl_packet_count() {
  local acl_text="$1" sequence="$2" count
  count="$(printf '%s\n' "$acl_text" | sed -nE \
    "s/^[[:space:]]*${sequence}[[:space:]].*\\[match ([0-9]+) packets,.*/\\1/p" | \
    head -n 1)"
  printf '%s\n' "${count:-0}"
}

check_counter_increased() {
  local name="$1" sequence="$2" before after
  before="$(acl_packet_count "$acl_before" "$sequence")"
  after="$(acl_packet_count "$acl_output" "$sequence")"
  if [[ "$before" =~ ^[0-9]+$ && "$after" =~ ^[0-9]+$ ]] && \
      (( after > before )); then
    pass "$name"
  else
    fail "$name" "sequence ${sequence} packets did not increase (${before} -> ${after})"
  fi
}

if tcp_open server 127.0.0.1 8080; then
  pass "server TCP/8080 listener is healthy"
else
  fail "server TCP/8080 listener is healthy" "local TCP/8080 is not listening"
fi

if tcp_open server 127.0.0.1 2222; then
  pass "server TCP/2222 listener is healthy"
else
  fail "server TCP/2222 listener is healthy" "local TCP/2222 is not listening"
fi

check_ping_linux "client -> server ICMP permitted" client 192.168.30.10
probe_allowed "client -> server TCP/8080 permitted" client 192.168.30.10 8080
probe_denied "client -> server TCP/2222 denied" client 192.168.30.10 2222

check_ping_linux "attacker -> server ICMP permitted" attacker 192.168.30.10
probe_denied "attacker -> server TCP/8080 denied" attacker 192.168.30.10 8080
probe_allowed "attacker host -> server TCP/2222 permitted" attacker 192.168.30.10 2222

check_ping_linux "unrelated client -> attacker transit is preserved" \
  client 192.168.20.10

acl_config="$(eos router 'show running-config | section ip access-list TRANSIT-IN')"
acl_before="$(eos router 'show ip access-lists TRANSIT-IN')"
ethernet1_config="$(eos router 'show running-config interfaces Ethernet1')"
ethernet2_config="$(eos router 'show running-config interfaces Ethernet2')"
ethernet3_config="$(eos router 'show running-config interfaces Ethernet3')"

check_contains "TRANSIT-IN uses exact per-entry counter mode" \
  "$acl_config" '^[[:space:]]*counters per-entry$'
check_contains "TRANSIT-IN contains exactly seven entries" \
  "$acl_before" '^[[:space:]]*Total rules configured:[[:space:]]+7$'

check_contains "sequence 10 is the exact trusted ICMP permit" "$acl_config" \
  '^[[:space:]]*10[[:space:]]+permit icmp 192\.168\.10\.0/24 host 192\.168\.30\.10$'
check_contains "sequence 20 is the exact trusted TCP/8080 permit" "$acl_config" \
  '^[[:space:]]*20[[:space:]]+permit tcp 192\.168\.10\.0/24 host 192\.168\.30\.10 eq 8080$'
check_contains "sequence 30 is the exact trusted TCP/2222 deny" "$acl_config" \
  '^[[:space:]]*30[[:space:]]+deny tcp 192\.168\.10\.0/24 host 192\.168\.30\.10 eq 2222$'
check_contains "sequence 40 is the exact untrusted ICMP permit" "$acl_config" \
  '^[[:space:]]*40[[:space:]]+permit icmp 192\.168\.20\.0/24 host 192\.168\.30\.10$'
check_contains "sequence 45 is the exact host TCP/2222 exception" "$acl_config" \
  '^[[:space:]]*45[[:space:]]+permit tcp host 192\.168\.20\.10 host 192\.168\.30\.10 eq 2222$'
check_contains "sequence 50 is the exact untrusted server TCP deny" "$acl_config" \
  '^[[:space:]]*50[[:space:]]+deny tcp 192\.168\.20\.0/24 host 192\.168\.30\.10$'
check_contains "sequence 60 is the exact unrelated-IP permit" "$acl_config" \
  '^[[:space:]]*60[[:space:]]+permit ip any any$'

check_contains "TRANSIT-IN is configured only on ingress Ethernet1-2" \
  "$acl_before" '^[[:space:]]*Configured on Ingress:[[:space:]]+Et1-2$'
check_contains "TRANSIT-IN is active only on ingress Ethernet1-2" \
  "$acl_before" '^[[:space:]]*Active on[[:space:]]+Ingress:[[:space:]]+Et1-2$'
check_not_contains "TRANSIT-IN has no egress attachment" \
  "$acl_before" 'Configured on Egress|Active on[[:space:]]+Egress'
check_contains "Ethernet1 has TRANSIT-IN inbound" "$ethernet1_config" \
  '^[[:space:]]*ip access-group TRANSIT-IN in$'
check_contains "Ethernet2 has TRANSIT-IN inbound" "$ethernet2_config" \
  '^[[:space:]]*ip access-group TRANSIT-IN in$'
check_not_contains "Ethernet3 has no ACL attachment" "$ethernet3_config" \
  'ip access-group'

# Generate one fresh flow for every rule after the before snapshot. Expected
# denies return non-zero; those failures are evidence, not checker failures.
docker exec "clab-${TOPO_NAME}-client" \
  ping -c2 -W2 192.168.30.10 &>/dev/null || true
tcp_open client 192.168.30.10 8080 || true
tcp_open client 192.168.30.10 2222 || true
docker exec "clab-${TOPO_NAME}-attacker" \
  ping -c2 -W2 192.168.30.10 &>/dev/null || true
tcp_open attacker 192.168.30.10 2222 || true
tcp_open attacker 192.168.30.10 8080 || true
docker exec "clab-${TOPO_NAME}-client" \
  ping -c2 -W2 192.168.20.10 &>/dev/null || true

acl_output="$(eos router 'show ip access-lists TRANSIT-IN')"
check_counter_increased "fresh trusted ICMP increments sequence 10" 10
check_counter_increased "fresh trusted TCP/8080 increments sequence 20" 20
check_counter_increased "fresh trusted TCP/2222 increments sequence 30" 30
check_counter_increased "fresh untrusted ICMP increments sequence 40" 40
check_counter_increased "fresh host TCP/2222 increments sequence 45" 45
check_counter_increased "fresh untrusted TCP/8080 increments sequence 50" 50
check_counter_increased "fresh unrelated transit increments sequence 60" 60

summary
