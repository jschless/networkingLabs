# Answer Key — MPLS Forwarding & VPNs

**Total:** 30 points

## A1 — Three label tables (3 points)

A FEC is a class of packets receiving the same forwarding treatment, commonly a prefix.
The LIB contains local and learned label bindings; liberal retention may keep bindings
from multiple neighbors. The LFIB contains only entries selected for actual label
forwarding according to the IGP next hop. (3)

## A2 — Global and local meaning (3 points)

`16000 + 3 = 16003`. Every SR node using the common SRGB interprets 16003 as pe2's node
segment. A VPN/PW label is allocated by the egress PE and is locally significant there:
it selects a VRF or attachment circuit rather than a network-wide node. (3)

## B1 — The IGP is healthy (8 points)

1. r1 still pushes label 18. r2 has no LFIB entry for 18, so the labeled packet is
   discarded instead of falling back to r2's unlabeled IP route. (3)
2. OSPF proves IP topology only. LDP signaling and kernel MPLS forwarding are distinct
   state; the r2-r3 LDP session or its binding/MPLS enablement can fail independently.
   (2)
3. Check r2's LDP discovery/session toward r3, then compare the binding for r4's FEC with
   r2's kernel/`show mpls table` entry and r3's advertised label. (2)
4. Source loopback-to-loopback traffic and capture/inspect the expected push, swap/PHP,
   plus end-to-end success. (1)

## C1 — Read a two-label L3VPN packet (6 points)

The outer 16003 is pe2's SR transport label derived from its node SID; it gets the packet
across the provider core. Inner 24000 was allocated and advertised by pe2 for the CUST-A
VPN route; it selects the egress VRF. A transit P swaps the outer label. The penultimate P
pops it after pe2 advertises implicit-null. pe2 receives the service label, selects
CUST-A, removes it, and forwards the customer IP packet toward the CE. (6)

## C2 — Export and import one VRF (4 points)

```text
address-family ipv4 unicast
 label vpn export auto
 rd vpn export 65000:101
 rt vpn both 65000:100
 export vpn
 import vpn
```

Award one point for label allocation, RD, RT, and both import/export commands together.

## D1 — LDP or Segment Routing? (6 points)

LDP discovers neighbors and maintains label-distribution sessions and per-FEC bindings
in addition to the IGP. SR advertises SID information as IGP extensions and derives node
labels from a common SRGB, eliminating LDP sessions. An inconsistent SRGB makes the same
numeric label mean different segments and breaks forwarding; LDP labels are locally
negotiated and do not require a shared block. Both designs still require MPLS enabled in
the kernel/interfaces and hop-by-hop LFIB/packet verification, not merely a healthy IGP.
(6)

## Remediation table

| Question | Labs |
|---|---|
| A1, B1 | `mpls-ldp` |
| A2, D1 | `mpls-sr-blank`, `mpls-sr-isis-bgp` |
| C1, C2 | `mpls-sr-blank`, `mpls-sr-isis-bgp`, `mpls-l2vpn` |
