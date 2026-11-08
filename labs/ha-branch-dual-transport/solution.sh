#!/usr/bin/env bash
# Apply the validated reference solution, cumulatively, through task N.
#
#   labs/ha-branch-dual-transport/solution.sh        # everything (tasks 2-8)
#   labs/ha-branch-dual-transport/solution.sh 5      # tasks 2-5 only
#
# This is the answer key. Use it to recover a broken attempt or to skip ahead
# to a later task, not as step one. Changes are applied to the running config
# and saved to startup-config on each cEOS node.
set -Eeuo pipefail

lab_dir=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=labs/ha-branch-dual-transport/lab-lib.sh
source "$lab_dir/lab-lib.sh"

THROUGH=${1:-8}
[[ "$THROUGH" =~ ^[2-8]$ ]] || { echo "Usage: $0 [2-8]" >&2; exit 2; }
hb_require_lab

task2() {   # MLAG pair + LACP everywhere
    local n peer
    for n in 1 2; do
        peer=$((3 - n))
        hb_eos_config "acc$n" <<EOF
no spanning-tree vlan-id 4094
vlan 4094
   trunk group MLAGPEER
interface Port-Channel1000
   description MLAG peer-link to acc$peer
   switchport mode trunk
   switchport trunk group MLAGPEER
interface Ethernet4-5
   channel-group 1000 mode active
interface Vlan4094
   no autostate
mlag configuration
   domain-id BRANCH
   local-interface Vlan4094
   peer-address 10.255.254.$peer
   peer-link Port-Channel1000
interface Port-Channel10
   description host1 (MLAG)
   switchport access vlan 10
   mlag 10
interface Ethernet1
   channel-group 10 mode active
interface Port-Channel11
   description br1 Po1 (MLAG)
   switchport access vlan 10
   mlag 11
interface Ethernet2
   channel-group 11 mode active
interface Port-Channel12
   description br2 Po1 (MLAG)
   switchport access vlan 10
   mlag 12
interface Ethernet3
   channel-group 12 mode active
EOF
    done
    for n in 1 2; do
        hb_eos_config "br$n" <<EOF
interface Port-Channel1
   description LACP to acc1/acc2 MLAG
   no switchport
   ip address 10.10.10.$((n + 1))/24
interface Ethernet2-3
   channel-group 1 mode active
EOF
    done
}

task3() {   # VRRP gateway
    hb_eos_config br1 <<'EOF'
interface Port-Channel1
   vrrp 10 priority-level 110
   vrrp 10 ipv4 10.10.10.1
EOF
    hb_eos_config br2 <<'EOF'
interface Port-Channel1
   vrrp 10 ipv4 10.10.10.1
EOF
}

task4() {   # Transports: eBGP to the PE, GRE + eBGP to the hub, iBGP across the cross-link
    hb_eos_config br1 <<'EOF'
router bgp 65010
   router-id 10.0.0.1
   neighbor 172.16.1.2 remote-as 65100
   neighbor 172.16.1.2 description MPLS PE
   neighbor 10.0.12.2 remote-as 65010
   neighbor 10.0.12.2 description br2 cross-link
   neighbor 10.0.12.2 next-hop-self
   network 10.10.10.0/24
EOF
    hb_eos_config br2 <<'EOF'
interface Tunnel0
   description GRE over Internet to hub
   mtu 1476
   ip address 10.99.0.1/30
   tunnel mode gre
   tunnel source 198.51.100.1
   tunnel destination 203.0.113.1
   tunnel path-mtu-discovery
   tunnel ttl 255
router bgp 65010
   router-id 10.0.0.2
   neighbor 10.99.0.2 remote-as 65000
   neighbor 10.99.0.2 description hub over GRE
   neighbor 10.0.12.1 remote-as 65010
   neighbor 10.0.12.1 description br1 cross-link
   neighbor 10.0.12.1 next-hop-self
   network 10.10.10.0/24
EOF
}

task5() {   # MPLS primary in BOTH directions
    hb_eos_config br1 <<'EOF'
route-map MPLS-IN permit 10
   set local-preference 200
router bgp 65010
   neighbor 172.16.1.2 route-map MPLS-IN in
EOF
    hb_eos_config br2 <<'EOF'
route-map HUB-OUT permit 10
   set as-path prepend 65010 65010
router bgp 65010
   neighbor 10.99.0.2 route-map HUB-OUT out
EOF
    hb_eos br1 'clear ip bgp 172.16.1.2 soft in' >/dev/null || true
    hb_eos br2 'clear ip bgp 10.99.0.2 soft out' >/dev/null || true
}

task6() {   # BFD on both eBGP sessions (provider side is already enabled)
    hb_eos_config br1 <<'EOF'
router bgp 65010
   neighbor 172.16.1.2 bfd
EOF
    hb_eos_config br2 <<'EOF'
router bgp 65010
   neighbor 10.99.0.2 bfd
EOF
}

task7() { :; }   # Task 7 is measurement only; no configuration.

task8() {   # Close the gaps: loopback iBGP over OSPF+BFD on two paths, VRRP tracking, edge ports
    local n peer
    for n in 1 2; do
        peer=$((3 - n))
        hb_eos_config "br$n" <<EOF
interface Loopback0
   ip ospf area 0.0.0.0
interface Ethernet4
   ip ospf network point-to-point
   ip ospf area 0.0.0.0
interface Port-Channel1
   ip ospf cost 100
   ip ospf area 0.0.0.0
router ospf 1
   router-id 10.0.0.$n
   passive-interface Loopback0
   bfd default
router bgp 65010
   no neighbor 10.0.12.$peer
   neighbor 10.0.0.$peer remote-as 65010
   neighbor 10.0.0.$peer description br$peer iBGP via loopback
   neighbor 10.0.0.$peer update-source Loopback0
   neighbor 10.0.0.$peer next-hop-self
EOF
    done
    hb_eos_config br1 <<'EOF'
track MPLS interface Ethernet1 line-protocol
interface Port-Channel1
   vrrp 10 tracked-object MPLS decrement 20
EOF
    for n in 1 2; do   # router- and host-facing ports are edge ports: no 20 s STP wait on link-up
        hb_eos_config "acc$n" <<'EOF'
interface Port-Channel10-12
   spanning-tree portfast
EOF
    done
}

for t in $(seq 2 "$THROUGH"); do
    echo "applying task $t"
    "task$t"
done
for n in "${HB_NODES_CEOS[@]}"; do hb_write_memory "$n"; done
echo "solution applied through task $THROUGH and saved; allow ~30 s for BGP/OSPF to converge"
