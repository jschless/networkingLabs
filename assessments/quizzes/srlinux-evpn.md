# Topic Quiz — SR Linux VXLAN-EVPN Operations

**Time:** 25 minutes · **Total:** 20 points · **Closed book, no CLI**

**Prerequisites:** `vxlan-evpn-srlinux`.

## Section 1 — Mechanisms (4 points)

### A1 — Control BUM and unicast forwarding (4 points)

Explain the roles of Type-3 IMET and Type-2 MAC/IP routes, the VTEP loopback underlay,
the VNI, and the SR Linux MAC-VRF. (4 pts)

## Section 2 — Evidence reading (6 points)

### B1 — Routes exchange, hosts do not

```text
vtep1 and vtep2 EVPN sessions: Established
Type-3 and Type-2 routes: present on both VTEPs
vtep1 mac-vrf VNI: 100
vtep2 mac-vrf VNI: 200
host1 -> host2: fail
```

Explain why the control plane remains partly healthy, localize the forwarding mismatch,
and give the minimum repair plus two checks. (6 pts)

## Section 3 — Application (5 points)

### C1 — Verify a remote MAC

Give an ordered evidence chain from host ARP through IMET flooding, remote MAC learning,
Type-2 reflection, VXLAN UDP encapsulation, and subsequent unicast forwarding. (5 pts)

## Section 4 — Design and troubleshooting (5 points)

### D1 — Translate concepts, not commands

Compare native SR Linux VXLAN/EVPN with a Linux/FRR implementation. Address native
tunnel/MAC-VRF state, control-plane learning preference, configuration model, and the
platform-independent evidence that must agree. (5 pts)

*Key: [`../answer-keys/quizzes/srlinux-evpn-key.md`](../answer-keys/quizzes/srlinux-evpn-key.md).*
