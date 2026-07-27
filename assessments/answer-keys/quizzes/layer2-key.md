# Answer Key — Layer 2 Topic Quiz

**Total:** 20 points

## A1 — Tags and tree roles (4 points)

1. An access port sends and receives ordinary untagged frames and assigns them to its
   configured VLAN internally. A trunk normally carries multiple VLANs with 802.1Q tags;
   its native VLAN is carried untagged and must agree at both ends. (2)
2. BPDU Guard belongs on a true PortFast host edge and disables/errdisables the port upon
   receiving a BPDU. Root Guard belongs on a boundary where a downstream switch may send
   BPDUs but must never become root; a superior BPDU puts the port into root-inconsistent
   rather than permanently disabling it, and it recovers when superior BPDUs stop. (2)

## B1 — One VLAN stops at the trunk (3 points)

sw2's trunk does not allow VLAN 20. VLAN 10 remains permitted on both ends, so only VLAN
20 traffic is pruned rather than the link failing entirely. Add VLAN 20 to the allowed
list on sw2 without replacing the intended list, confirm both ends show VLANs 10 and 20,
and run a VLAN-20 host-to-host ping across the switches. (3)

Award one point each for fault/mechanism, minimal repair, and end-host verification.

## B2 — Members that never bundle (3 points)

Passive LACP waits for received LACPDUs. With both sides passive, neither initiates, so
members remain individual/standalone and Po1 stays down. Change at least one side to
`channel-group 1 mode active`; active/active is operationally clearest. Static `mode on`
removes negotiation and partner validation, so mismatched cabling or configuration can
forward unsafely or create a loop instead of refusing to bundle. (3)

## C1 — Protected user edge and constrained trunk (5 points)

```text
interface Ethernet5
   switchport mode access
   switchport access vlan 30
   spanning-tree portfast
   spanning-tree bpduguard enable

interface Ethernet48
   switchport mode trunk
   switchport trunk native vlan 1
   switchport trunk allowed vlan 10,20,30
```

- access mode and VLAN 30: 1.5
- PortFast only on the host edge: 1
- BPDU Guard only on the host edge: 1
- trunk mode and exact allowed list: 1
- native VLAN 1: 0.5

Do not award the protection points if PortFast or BPDU Guard is placed on the
inter-switch trunk without an explicitly justified edge design.

## D1 — A degraded bundle is still “up” (5 points)

1. The logical Port-Channel remains up through the surviving member, so its IP interface
   and OSPF adjacency do not fail. EOS selects a member with a header-field hash per
   flow; per-packet alternation would reorder traffic, and one large flow can therefore
   saturate one member. (2)
2. `port-channel min-links 2` makes the logical interface go down when fewer than two
   members are active. That forces routing to reconverge before the half-capacity path
   overloads, but it deliberately sacrifices connectivity that one surviving link might
   still have provided. (2)
3. Require both: inspect Port-Channel/member/LACP state and the OSPF neighbor or alternate
   route, then inspect member utilization or run representative multi-flow traffic with
   loss/latency measurements. (1)

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1.1, B1, C1 | Access/trunk tagging, native VLAN, allowed-list pruning | `vlan-trunks-switchport-basics` |
| A1.2, C1 | PortFast, BPDU Guard, Root Guard | `campus-l2-hardening`, `stp-operations` |
| B2, D1 | LACP negotiation, hashing, member failure, min-links | `lacp-etherchannel` |
