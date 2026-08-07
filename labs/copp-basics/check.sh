#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init "copp-basics"

check_equal() {
    local name="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "expected '$expected', got '$actual'"
    fi
}

check_exact_learned() {
    local name="$1" actual="$2" expected="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "learned state differs from the required exact definition"
    fi
}

safe_node() {
    node "$1" "$2" || true
}

safe_frr() {
    frr "$1" "$2" || true
}

container_image() {
    docker inspect "clab-${TOPO_NAME}-$1" --format '{{.Config.Image}}' 2>/dev/null || true
}

exact_address() {
    local node_name="$1" interface="$2" expected="$3" actual
    actual="$(safe_node "$node_name" "ip -4 -o address show dev $interface scope global | awk '{print \$4}'")"
    [[ "$actual" == "$expected" ]]
}

icmp_counters() {
    safe_node r2 "iptables -L COPP-ICMP -n -v -x --line-numbers | awk '\$1 == 1 { accepted = \$2 } \$1 == 2 { dropped = \$2 } END { print accepted + 0, dropped + 0 }'"
}

expected_inventory="$(printf '%s\n' \
    clab-copp-basics-r1 \
    clab-copp-basics-r2 \
    clab-copp-basics-r3 | sort)"
actual_inventory="$(docker ps --format '{{.Names}}' | grep '^clab-copp-basics-' | sort)"
check_equal "exact three-node inventory" "$actual_inventory" "$expected_inventory"

if [[ "$(container_image r1)" == "copp-lab:local" &&
      "$(container_image r2)" == "copp-lab:local" &&
      "$(container_image r3)" == "copp-lab:local" ]]; then
    pass "exact purpose-built image on every node"
else
    fail "exact purpose-built image on every node" "expected copp-lab:local on r1, r2, and r3"
fi

if exact_address r1 lo 10.0.0.1/32 &&
   exact_address r1 eth1 10.1.12.1/30 &&
   exact_address r2 lo 10.0.0.2/32 &&
   exact_address r2 eth1 10.1.12.2/30 &&
   exact_address r2 eth2 10.1.23.1/30 &&
   exact_address r3 lo 10.0.0.3/32 &&
   exact_address r3 eth1 10.1.23.2/30; then
    pass "exact loopback and data-link addressing"
else
    fail "exact loopback and data-link addressing" "one or more interface addresses differ"
fi

r1_bgp="$(safe_frr r1 'show bgp neighbor 10.1.12.2')"
r2_bgp="$(safe_frr r2 'show bgp neighbor 10.1.12.1')"
if grep -q 'BGP state = Established' <<< "$r1_bgp" &&
   grep -q 'BGP state = Established' <<< "$r2_bgp"; then
    pass "reciprocal eBGP session established"
else
    fail "reciprocal eBGP session established" "r1-r2 is not Established in both views"
fi

r2_ospf="$(safe_frr r2 'show ip ospf neighbor')"
r3_ospf="$(safe_frr r3 'show ip ospf neighbor')"
if grep -Eq '10\.0\.0\.3[[:space:]].*Full' <<< "$r2_ospf" &&
   grep -Eq '10\.0\.0\.2[[:space:]].*Full' <<< "$r3_ospf"; then
    pass "reciprocal OSPF adjacency full"
else
    fail "reciprocal OSPF adjacency full" "r2-r3 is not Full in both views"
fi

if docker exec "clab-${TOPO_NAME}-r1" ping -q -c 3 -w 6 -I 10.0.0.1 10.0.0.3 >/dev/null 2>&1 &&
   docker exec "clab-${TOPO_NAME}-r3" ping -q -c 3 -w 6 -I 10.0.0.3 10.0.0.1 >/dev/null 2>&1; then
    pass "bidirectional loopback traffic transits r2"
else
    fail "bidirectional loopback traffic transits r2" "one or both sourced loopback probes failed"
fi

expected_copp="$(cat <<'EOF'
-N COPP
-A COPP -p tcp -m tcp --dport 179 -j COPP-BGP
-A COPP -p tcp -m tcp --sport 179 -j COPP-BGP
-A COPP -p 89 -j COPP-OSPF
-A COPP -p icmp -m icmp --icmp-type 8 -j COPP-ICMP
-A COPP -j RETURN
EOF
)"
expected_bgp="$(cat <<'EOF'
-N COPP-BGP
-A COPP-BGP -m limit --limit 60/sec --limit-burst 120 -j ACCEPT
-A COPP-BGP -j DROP
EOF
)"
expected_ospf="$(cat <<'EOF'
-N COPP-OSPF
-A COPP-OSPF -m limit --limit 30/sec --limit-burst 60 -j ACCEPT
-A COPP-OSPF -j DROP
EOF
)"
expected_icmp="$(cat <<'EOF'
-N COPP-ICMP
-A COPP-ICMP -m limit --limit 2/sec --limit-burst 4 -j ACCEPT
-A COPP-ICMP -j DROP
EOF
)"

check_exact_learned "exact classifier dispatch" "$(safe_node r2 'iptables -S COPP')" "$expected_copp"
check_exact_learned "exact BGP policer definition" "$(safe_node r2 'iptables -S COPP-BGP')" "$expected_bgp"
check_exact_learned "exact OSPF policer definition" "$(safe_node r2 'iptables -S COPP-OSPF')" "$expected_ospf"
check_exact_learned "exact ICMP policer definition" "$(safe_node r2 'iptables -S COPP-ICMP')" "$expected_icmp"

saved="$(safe_node r2 'cat /etc/copp.rules.v4')"
saved_declarations="$(grep -E '^:COPP(-BGP|-OSPF|-ICMP)? ' <<< "$saved" || true)"
expected_saved_declarations="$(cat <<'EOF'
:COPP - [0:0]
:COPP-BGP - [0:0]
:COPP-ICMP - [0:0]
:COPP-OSPF - [0:0]
EOF
)"
saved_first_input="$(awk '$1 == "-A" && $2 == "INPUT" { print; exit }' <<< "$saved")"
saved_input_count="$(grep -c '^-A INPUT -j COPP$' <<< "$saved" || true)"
saved_custom="$(grep -E '^-A COPP(-BGP|-OSPF|-ICMP)? ' <<< "$saved" || true)"
expected_saved_custom="$(cat <<'EOF'
-A COPP -p tcp -m tcp --dport 179 -j COPP-BGP
-A COPP -p tcp -m tcp --sport 179 -j COPP-BGP
-A COPP -p 89 -j COPP-OSPF
-A COPP -p icmp -m icmp --icmp-type 8 -j COPP-ICMP
-A COPP -j RETURN
-A COPP-BGP -m limit --limit 60/sec --limit-burst 120 -j ACCEPT
-A COPP-BGP -j DROP
-A COPP-ICMP -m limit --limit 2/sec --limit-burst 4 -j ACCEPT
-A COPP-ICMP -j DROP
-A COPP-OSPF -m limit --limit 30/sec --limit-burst 60 -j ACCEPT
-A COPP-OSPF -j DROP
EOF
)"
saved_restore_test=false
if node r2 'iptables-restore --test < /etc/copp.rules.v4' >/dev/null 2>&1; then
    saved_restore_test=true
fi
if [[ "$saved_declarations" == "$expected_saved_declarations" &&
      "$saved_first_input" == "-A INPUT -j COPP" &&
      "$saved_input_count" == "1" &&
      "$saved_custom" == "$expected_saved_custom" ]] &&
   "$saved_restore_test"; then
    pass "saved policy matches the healthy reference"
else
    fail "saved policy matches the healthy reference" "saved learned state differs from the required healthy reference"
fi

input_rules="$(safe_node r2 'iptables -S INPUT')"
first_input="$(awk '/^-A INPUT / { print; exit }' <<< "$input_rules")"
input_jump_count="$(grep -c '^-A INPUT -j COPP$' <<< "$input_rules" || true)"

sleep 3
read -r accepted_before dropped_before <<< "$(icmp_counters)"
docker exec "clab-${TOPO_NAME}-r3" ping -q -c 20 -i 0.02 -w 2 10.1.23.1 >/dev/null 2>&1 || true
read -r accepted_after dropped_after <<< "$(icmp_counters)"

transit_counter_before=$((accepted_after + dropped_after))
transit_ok=0
if docker exec "clab-${TOPO_NAME}-r1" ping -q -c 3 -w 6 -I 10.0.0.1 10.0.0.3 >/dev/null 2>&1; then
    transit_ok=1
fi
read -r accepted_transit_after dropped_transit_after <<< "$(icmp_counters)"
transit_counter_after=$((accepted_transit_after + dropped_transit_after))

if [[ "$first_input" == "-A INPUT -j COPP" && "$input_jump_count" == "1" ]] &&
   (( accepted_after > accepted_before && dropped_after > dropped_before )) &&
   (( transit_ok == 1 && transit_counter_after == transit_counter_before )); then
    pass "bounded local-versus-transit enforcement"
else
    fail "bounded local-versus-transit enforcement" "runtime attachment, local accept/drop deltas, or transit isolation did not match"
fi

r2_bgp_after="$(safe_frr r2 'show bgp neighbor 10.1.12.1')"
r2_ospf_after="$(safe_frr r2 'show ip ospf neighbor')"
check_contains "BGP remains healthy after bounded traffic" "$r2_bgp_after" 'BGP state = Established'
check_contains "OSPF remains healthy after bounded traffic" "$r2_ospf_after" '10\.0\.0\.3[[:space:]].*Full'

summary
