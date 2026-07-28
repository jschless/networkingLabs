# Topic Quiz — Layer 2

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `vlan-trunks-switchport-basics`, `campus-l2-hardening`,
`stp-operations`, and `lacp-etherchannel`.

Configuration syntax is Arista EOS as used by the labs.

---

## Section 1 — Mechanisms (4 points)

### A1 — Tags and tree roles (4 points)

1. Explain how an access port and an 802.1Q trunk carry frames for the same VLAN,
   including what is special about the native VLAN. (2 pts)
2. Contrast BPDU Guard and Root Guard: where each belongs and the different state change
   caused by receiving the BPDU each feature is designed to reject. (2 pts)

---

## Section 2 — Evidence reading (6 points)

### B1 — One VLAN stops at the trunk (3 points)

VLAN 10 hosts communicate across sw1 and sw2. VLAN 20 hosts on the same two switches do
not.

```text
sw1# show interfaces trunk
Port       Mode   Native  Allowed Vlans
Et48       trunk  1       10,20

sw2# show interfaces trunk
Port       Mode   Native  Allowed Vlans
Et48       trunk  1       10
```

Identify the fault, explain why it creates selective rather than total failure, and state
the minimal repair plus one end-host verification. (3 pts)

### B2 — Members that never bundle (3 points)

```text
sw1# show port-channel summary
Group  Port-Channel  Protocol  Ports
1      Po1(SD)       LACP      Et1(I) Et2(I)

sw1# show lacp counters
Port  LACPDUs Sent  LACPDUs Received
Et1   0             0
Et2   0             0
```

Both sw1 and sw2 have `channel-group 1 mode passive` on both members.

Explain the state, give the minimal repair, and state why changing both sides to static
`mode on` would be a riskier repair. (3 pts)

---

## Section 3 — Application (5 points)

### C1 — Protected user edge and constrained trunk

Write EOS configuration that:

- places `Ethernet5` in access VLAN 30;
- enables PortFast and BPDU Guard on that true user-facing port;
- makes `Ethernet48` a trunk carrying only VLANs 10, 20, and 30;
- leaves the trunk native VLAN at 1.

Assume the VLANs already exist.

---

## Section 4 — Design and troubleshooting (5 points)

### D1 — A degraded bundle is still “up”

A routed two-member Port-Channel carries an OSPF adjacency. One member fails and the
bundle remains up, but monitoring shows the remaining link is saturated.

1. Explain why OSPF did not reconverge and why individual packets are not normally
   sprayed alternately across both members. (2 pts)
2. Explain what `port-channel min-links 2` would change, including its benefit and
   availability trade-off. (2 pts)
3. Give one control-plane and one traffic/capacity check after choosing a policy. (1 pt)

---

<!-- site-include-end -->

*End of Layer 2 quiz. Key:
[`../answer-keys/quizzes/layer2-key.md`](../answer-keys/quizzes/layer2-key.md).*
