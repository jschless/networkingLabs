#!/usr/bin/env bash
# Read-only grader for the Task 8 end state of ha-branch-dual-transport.
set -u

REPO_ROOT=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=scripts/check-lib.sh
source "$REPO_ROOT/scripts/check-lib.sh"
# shellcheck source=labs/ha-branch-dual-transport/lab-lib.sh
source "$REPO_ROOT/labs/ha-branch-dual-transport/lab-lib.sh"
lab_init ha-branch-dual-transport

echo '--- Task 2: MLAG + LACP'
for n in acc1 acc2; do
    out=$(eos "$n" 'show mlag')
    check_contains "$n MLAG state Active" "$out" 'state +: +Active'
    check_contains "$n MLAG peer config consistent" "$out" 'peer-config +: +consistent'
    out=$(eos "$n" 'show mlag interfaces')
    for m in 10 11 12; do
        check_contains "$n mlag $m active-full up/up" "$out" "^ +$m +.* active-full +Po$m +Po$m +up/up"
    done
done
for n in br1 br2; do
    out=$(eos "$n" 'show port-channel 1 detailed')
    check_contains "$n Po1 bundles Ethernet2" "$out" 'Ethernet2 +[0-9:]+ +LACP +Active +[0-9]+ +Rx,Tx'
    check_contains "$n Po1 bundles Ethernet3" "$out" 'Ethernet3 +[0-9:]+ +LACP +Active +[0-9]+ +Rx,Tx'
done
out=$(node host1 'cat /proc/net/bonding/bond0')
check_contains 'host1 bond is 802.3ad' "$out" '802\.3ad'
agg=$(grep -c 'Aggregator ID: 1' <<<"$out" || true)
if [[ $agg -ge 3 ]]; then pass 'host1 both bond legs in one aggregator'; else fail 'host1 both bond legs in one aggregator' 'one leg is not aggregated (MLAG not presenting one system?)'; fi

echo '--- Task 3: VRRP'
check_contains 'br1 is VRRP Master for 10.10.10.1' "$(eos br1 'show vrrp brief')" 'Po1 +default +10 +.* Master .*10\.10\.10\.1'
check_contains 'br2 is VRRP Backup for 10.10.10.1' "$(eos br2 'show vrrp brief')" 'Po1 +default +10 +.* Backup .*10\.10\.10\.1'

echo '--- Tasks 4/8: BGP sessions'
out=$(eos br1 'show ip bgp summary')
check_contains 'br1 eBGP to MPLS PE Established' "$out" '172\.16\.1\.2 +4 +65100 .*Estab'
check_contains 'br1 iBGP to br2 loopback Established' "$out" '10\.0\.0\.2 +4 +65010 .*Estab'
out=$(eos br2 'show ip bgp summary')
check_contains 'br2 eBGP to hub over GRE Established' "$out" '10\.99\.0\.2 +4 +65000 .*Estab'
check_contains 'br2 iBGP to br1 loopback Established' "$out" '10\.0\.0\.1 +4 +65010 .*Estab'
for n in br1 br2; do
    if [[ $n == br1 ]]; then peer=10.0.0.2; else peer=10.0.0.1; fi
    check_contains "$n OSPF Full to its peer over the cross-link" "$(eos "$n" 'show ip ospf neighbor')" "^$peer .*FULL.*Ethernet4"
    check_contains "$n OSPF adjacency also over Po1 (backup path)" "$(eos "$n" 'show ip ospf neighbor')" "^$peer .*FULL.*Port-Channel1"
done

echo '--- Task 5: path policy'
# one path entry spans two lines; flatten so the regex can tie localpref to "best"
lp200='localpref 200, IGP metric [0-9]+, weight [0-9]+, tag [0-9]+ +Received [^,]+, valid'
out=$(eos br1 'show ip bgp 10.20.20.0/24' | tr '\n' ' ')
check_contains 'br1 best path to DC is via MPLS with LP 200' "$out" "$lp200, external, best"
out=$(eos br2 'show ip bgp 10.20.20.0/24' | tr '\n' ' ')
check_contains 'br2 prefers br1 (iBGP, LP 200) over its own tunnel' "$out" "$lp200, internal, best"
out=$(frr hub 'show ip bgp 10.10.10.0/24')
check_contains 'hub sees the prepended tunnel path' "$out" '65010 65010 65010'
fwd=$(node hub 'ip route get 10.10.10.100')
check_contains 'hub forwards to the branch via the MPLS PE' "$fwd" 'via 172\.16\.2\.2'
fwd=$(eos br1 'show ip route 10.20.20.0/24')
check_contains 'br1 forwards to the DC via the MPLS PE' "$fwd" 'via 172\.16\.1\.2'

echo '--- Task 6: BFD'
check_contains 'br1 BFD to MPLS PE Up' "$(eos br1 'show bfd peers')" '172\.16\.1\.2 .*Ethernet1'
check_contains 'br1 BFD state Up' "$(eos br1 'show bfd peers')" 'Up'
check_contains 'br2 BFD over Tunnel0 to hub Up' "$(eos br2 'show bfd peers')" '10\.99\.0\.2 .*Tunnel0'
out=$(frr mpls 'show bfd peers brief')
check_contains 'PE sees BFD to br1 up' "$out" '172\.16\.1\.1 +up'
out=$(frr hub 'show bfd peers brief')
check_contains 'hub sees BFD to br2 up' "$out" '10\.99\.0\.1 +up'

echo '--- Task 8: tracking'
out=$(eos br1 'show track')
check_contains 'br1 tracks the MPLS circuit' "$out" 'Interface Ethernet1 line-protocol'
check_contains 'br1 VRRP is a client of the track' "$out" 'Tracked by:[[:space:]]*$|VRRP|Vrrp|Port-Channel1'
check_contains 'br1 VRRP decrement configured' "$(eos br1 'show running-config interfaces Port-Channel1')" 'vrrp 10 tracked-object MPLS decrement 20'
for n in br1 br2; do
    check_contains "$n OSPF uses BFD" "$(eos "$n" 'show running-config section router ospf')" 'bfd default'
done
for n in acc1 acc2; do
    for p in 10 11 12; do
        # auto-edge also shows "Edge", but only after a ~20 s wait on link-up; require explicit portfast
        check_contains "$n Po$p is configured as an edge port (portfast)" \
            "$(eos "$n" "show running-config interfaces Port-Channel$p")" 'spanning-tree portfast'
    done
done

echo '--- End to end'
out=$(node host1 'ping -c 10 -i 0.2 -W 1 10.20.20.100')
check_contains 'host1 reaches server with no loss' "$out" ' 0% packet loss'
check_not_contains 'host1 sees no duplicate replies' "$out" 'DUP'
out=$(node host1 'traceroute -n -q 1 -w 1 -m 5 10.20.20.100')
check_contains 'forward path uses MPLS (172.16.1.2)' "$out" '172\.16\.1\.2'
out=$(node server 'traceroute -n -q 1 -w 1 -m 5 10.10.10.100')
check_contains 'return path uses MPLS (172.16.2.2)' "$out" '172\.16\.2\.2'

summary
