# Topic Quiz — MPLS Forwarding & VPNs

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `mpls-ldp`, `mpls-sr-blank`, `mpls-sr-isis-bgp`, and
`mpls-l2vpn`. `bgp-labeled-unicast` is recommended.

---

## Section 1 — Mechanisms (6 points)

### A1 — Three label tables (3 points)

Define a FEC, distinguish the LIB from the LFIB, and explain why an LDP router may retain
several remote bindings for a FEC while installing only one forwarding entry. (3 pts)

### A2 — Global and local meaning (3 points)

The SRGB starts at 16000 and pe2 advertises node SID index 3. Compute its transport label.
Then contrast the scope of that node label with a VPN or pseudowire service label
allocated by the egress PE. (3 pts)

---

## Section 2 — Evidence reading (8 points)

### B1 — The IGP is healthy

```text
r1# show ip route 10.0.0.4/32
O 10.0.0.4/32 via 10.1.12.2, eth1, label 18

r1# show mpls ldp neighbor
10.0.0.2 OPERATIONAL

r2# show ip route 10.0.0.4/32
O 10.0.0.4/32 via 10.1.23.2, eth2

r2# show mpls table
In Label  Type  Nexthop
16        LDP   10.1.12.1
17        LDP   10.1.23.2

r2# show mpls ldp neighbor
10.0.0.1 OPERATIONAL
```

OSPF remains Full end to end, but loopback-to-loopback traffic from r1 to r4 fails.

1. Explain the label-plane black hole, including what happens when label 18 reaches r2.
   (3 pts)
2. Why can the IP control plane remain healthy while labeled traffic fails? (2 pts)
3. Give two ordered checks that localize the missing state beyond what is shown. (2 pts)
4. State a repair verification that proves the label path, not only IP reachability.
   (1 pt)

---

## Section 3 — Application (10 points)

### C1 — Read a two-label L3VPN packet (6 points)

pe1 sends customer traffic toward a prefix in VRF CUST-A on pe2. It pushes outer label
16003 and inner label 24000.

1. Identify who assigned each label and what forwarding decision each label represents.
   (3 pts)
2. Walk the stack through a transit P router, the penultimate P router using PHP, and
   pe2. (3 pts)

### C2 — Export and import one VRF (4 points)

Under `router bgp 65000 vrf CUST-A`, write the FRR IPv4-unicast address-family commands
that automatically allocate a VPN label, export with RD `65000:101`, import and export
RT `65000:100`, and enable VPN import/export.

---

## Section 4 — Design and troubleshooting (6 points)

### D1 — LDP or Segment Routing?

Compare LDP and SR-MPLS for a five-router core. Address signaling sessions, where label
state comes from, the effect of inconsistent SRGBs, and one operational check common to
both approaches before declaring an LSP healthy. (6 pts)

---

<!-- site-include-end -->

*End of MPLS quiz. Key:
[`../answer-keys/quizzes/mpls-key.md`](../answer-keys/quizzes/mpls-key.md).*
