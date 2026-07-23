#!/usr/bin/env bash
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/check-lib.sh"
lab_init carrier-ethernet-handoff
flows_a="$(node nid-a 'ovs-ofctl -O OpenFlow13 dump-flows br-service')"
flows_b="$(node nid-b 'ovs-ofctl -O OpenFlow13 dump-flows br-service')"
check_contains 'NID-A VLAN 110 maps S-VLAN 3100' "$flows_a" 'set_field:7196->vlan_vid'
check_contains 'NID-A VLAN 120 maps S-VLAN 3120' "$flows_a" 'set_field:7216->vlan_vid'
check_contains 'NID-B VLAN 120 maps S-VLAN 3120' "$flows_b" 'set_field:7216->vlan_vid'
check_ping_linux 'VLAN 110 A to B' tester-a 192.0.2.2 192.0.2.1
check_ping_linux 'VLAN 110 B to A' tester-b 192.0.2.1 192.0.2.2
check_ping_linux 'VLAN 120 A to B' tester-a 198.51.100.2 198.51.100.1
check_ping_linux 'VLAN 120 B to A' tester-b 198.51.100.1 198.51.100.2
if ! node tester-a 'ping -I eth1.110 -c2 -W2 198.51.100.2' >/dev/null; then pass 'VLAN 110 cannot reach VLAN 120'; else fail 'VLAN 110 cannot reach VLAN 120' 'cross-service ping succeeded'; fi
if node tester-a 'ping -I eth1.110 -M do -c1 -W2 -s1572 192.0.2.2' >/dev/null; then pass '1600-byte service MTU passes'; else fail '1600-byte service MTU passes' 'probe failed'; fi
if ! node tester-a 'ping -I eth1.110 -M do -c1 -W2 -s1573 192.0.2.2' >/dev/null; then pass 'one byte above MTU fails'; else fail 'one byte above MTU fails' 'probe unexpectedly passed'; fi
check_contains 'PCP rewrite policy is installed' "$flows_a" 'set_field:5->vlan_pcp|set_field:0x5->vlan_pcp'
check_not_contains 'Customer data cannot use provider management' "$(node tester-a 'ip route')" '10\.70\.'
summary
