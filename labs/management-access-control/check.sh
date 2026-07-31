#!/usr/bin/env bash
# Assert the solved cEOS management-plane policy and generate fresh evidence.
set -u

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "management-access-control"

probe_allowed() {
  local name="$1" node_name="$2" address="$3" port="$4"
  if docker exec "clab-${TOPO_NAME}-${node_name}" \
      nc -zw3 "$address" "$port" &>/dev/null; then
    pass "$name"
  else
    fail "$name" "TCP/${port} is not reachable from ${node_name}"
  fi
}

probe_denied() {
  local name="$1" node_name="$2" address="$3" port="$4"
  if ! docker exec "clab-${TOPO_NAME}-${node_name}" \
      nc -zw3 "$address" "$port" &>/dev/null; then
    pass "$name"
  else
    fail "$name" "TCP/${port} is unexpectedly reachable from ${node_name}"
  fi
}

acl_packet_count() {
  local acl_text="$1" sequence="$2" count
  count="$(printf '%s\n' "$acl_text" | sed -nE \
    "s/^[[:space:]]*${sequence}[[:space:]].* in ([0-9]+) packets.*/\\1/p" | head -n 1)"
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

acl_before="$(eos device1 'show ip access-lists MGMT-PLANE')"

probe_allowed "admin1 -> device1 SSH permitted" admin1 192.168.99.1 22
probe_allowed "admin1 -> device1 HTTPS eAPI permitted" admin1 192.168.99.1 443
probe_denied "guest1 -> device1 SSH denied" guest1 192.168.50.1 22
probe_denied "guest1 -> device1 HTTPS eAPI denied" guest1 192.168.50.1 443

check_ping_linux "admin1 -> device1 ICMP preserved" admin1 192.168.99.1
check_ping_linux "guest1 -> device1 ICMP preserved" guest1 192.168.50.1

api_output="$(eos device1 'show management api http-commands')"
check_contains "device1 eAPI is administratively enabled" "$api_output" \
  '^Enabled:[[:space:]]+Yes$'
check_contains "device1 offers HTTPS eAPI on TCP/443" "$api_output" \
  '^HTTPS server:[[:space:]]+running, set to use port 443$'
check_contains "device1 plaintext HTTP eAPI is shut down" "$api_output" \
  '^HTTP server:[[:space:]]+shutdown, set to use port 80$'

acl_output="$(eos device1 'show ip access-lists MGMT-PLANE')"
ethernet1_config="$(eos device1 'show running-config interfaces Ethernet1')"
ethernet2_config="$(eos device1 'show running-config interfaces Ethernet2')"

check_contains "MGMT-PLANE is configured inbound on the control plane" \
  "$acl_output" '^[[:space:]]*Configured on Ingress:[[:space:]]+control-plane\(default VRF\)'
check_contains "MGMT-PLANE is active inbound on the control plane" \
  "$acl_output" '^[[:space:]]*Active on[[:space:]]+Ingress:[[:space:]]+control-plane\(default VRF\)'
check_contains "MGMT-PLANE contains exactly the five intended entries" \
  "$acl_output" '^[[:space:]]*Total rules configured:[[:space:]]+5$'
check_not_contains "Ethernet1 has no data-plane ACL attachment" \
  "$ethernet1_config" 'ip access-group'
check_not_contains "Ethernet2 has no data-plane ACL attachment" \
  "$ethernet2_config" 'ip access-group'

check_contains "sequence 10 is the exact admin SSH permit" "$acl_output" \
  '^[[:space:]]*10[[:space:]]+permit tcp 192\.168\.99\.0/24 any eq ssh([[:space:]]|$)'
check_contains "sequence 20 is the exact admin HTTPS permit" "$acl_output" \
  '^[[:space:]]*20[[:space:]]+permit tcp 192\.168\.99\.0/24 any eq https([[:space:]]|$)'
check_contains "sequence 30 is the exact other-source SSH deny" "$acl_output" \
  '^[[:space:]]*30[[:space:]]+deny tcp any any eq ssh([[:space:]]|$)'
check_contains "sequence 40 is the exact other-source HTTPS deny" "$acl_output" \
  '^[[:space:]]*40[[:space:]]+deny tcp any any eq https([[:space:]]|$)'
check_contains "sequence 50 is the exact unrelated-IP permit" "$acl_output" \
  '^[[:space:]]*50[[:space:]]+permit ip any any([[:space:]]|$)'

check_counter_increased "fresh admin SSH traffic increments sequence 10" 10
check_counter_increased "fresh admin HTTPS traffic increments sequence 20" 20
check_counter_increased "fresh guest SSH traffic increments sequence 30" 30
check_counter_increased "fresh guest HTTPS traffic increments sequence 40" 40
check_counter_increased "fresh unrelated IP traffic increments sequence 50" 50

summary
