# Exam A — Core Routing & Switching

**Time:** 2 hours · **Total:** 100 points · **Closed book, no CLI**

Covers the OSPF, EIGRP, IS-IS, BGP, Route Control, and Layer 2 tracks, plus the lab
harness itself.

Write configuration in the syntax of the platform named in the question — Arista EOS for
the cEOS labs, FRR for the FRR labs. Syntax is graded for correctness, not for style;
a stanza that would not commit loses points, a stanza that commits but is ugly does not.

---

## Section 1 — Concepts & mechanisms (30 points)

Ten questions, 3 points each. Two to four sentences is the right length; a one-word
answer will not score full marks even when the word is right.

**A1.** In `ospf-nssa`, r1 is the ASBR inside area 1, r2 is the ABR, and r3 sits in
area 0. Before the area became NSSA, r3 saw the external prefix as a Type-5 LSA
advertised by 10.0.0.1. After the conversion, r3 *still* sees a Type-5 — but the
advertising router changed to 10.0.0.2.

(a) Why did the advertising router change? (b) Which LSA type carries that prefix
*inside* area 1? (c) What does the P-bit do, and who sets it?

**A2.** You configure `area 1 nssa` on r1 but have not yet configured it on r2. The
r1–r2 adjacency drops immediately — not to `ExStart`, not to `2-Way`, but to nothing at
all. Which specific field in which packet caused that, and name one other
misconfiguration with the same "neighbors never appear" signature.

**A3.** Totally-NSSA. Which router gets the extra keyword, what is the keyword, and what
route type does the default route appear as on r1 — `O IA`, `O E2`, or `O N2`? Why that
one?

**A4.** Define feasible distance (FD) and reported distance (RD), state the feasibility
condition as an inequality, and explain in one sentence why EIGRP enforces it rather than
simply installing whatever the `variance` multiplier allows.

**A5.** In `bgp-path-selection` Task 1, ce1 has two paths to 10.0.0.4/32 that are
identical through rule 8 of the selection list. Which rules actually break the tie, and
why does the lab describe the result as operationally dangerous rather than merely
arbitrary?

**A6.** You set `neighbor 10.1.11.2 weight 200` on ce1. Explain why this changes nothing
about (a) isp2's own path choice and (b) the path that traffic *into* ce1 takes. Name the
attribute you would reach for instead if you needed to influence (b), and state its
limitation.

**A7.** For IS-IS: break down the NET `49.0001.0000.0000.0002.00` into its three parts.
Then give two behavioural differences between the IS-IS DIS and the OSPF DR — not
configuration differences, election or operational ones.

**A8.** Mutual redistribution between two IGPs at two different routers can produce a
routing loop or a permanently suboptimal path. Explain the tag-based prevention mechanism
used in `redistribution-tags`: what gets tagged, where, and what the filter does.

**A9.** Every FRR BGP instance in this repo carries `no bgp ebgp-requires-policy`. Which
RFC behaviour is that switch disabling, what exactly happens on an eBGP session without
it and without any policy, and why is the symptom easy to misdiagnose as a session
problem?

**A10.** PortFast, BPDU Guard, and Root Guard from `campus-l2-hardening`. For each: what
it protects against, and which port role it belongs on. Then state what happens to a port
with BPDU Guard that receives a BPDU, and what happens to a port with Root Guard that
receives a *superior* BPDU — the two outcomes are not the same.

---

## Section 2 — Evidence reading (20 points)

You did not run these commands and you cannot run any others. Diagnose from what is on
the page.

### B1 (8 points)

On ce1 in the `bgp-path-selection` topology:

```text
ce1#show bgp ipv4 unicast 10.0.0.4/32
BGP routing table entry for 10.0.0.4/32
 Paths: 2 available
  65100 65002
    10.1.12.2 from 10.1.12.2 (10.0.0.3)
      Origin IGP, metric 0, localpref 100, weight 0, valid, external, best
  65100 65100 65100 65002
    10.1.11.2 from 10.1.11.2 (10.0.0.2)
      Origin IGP, metric 0, localpref 100, weight 0, valid, external
```

(a) Which rule in the selection list decided this, and at which step did the walk stop?
(2 pts)
(b) Somebody configured something to produce this. What, and on which router, and in
which direction? (3 pts)
(c) If ce1 now sets `neighbor 10.1.11.2 weight 200`, does the best path move? Justify
using the rule numbers. (2 pts)
(d) Does the change in (c) affect what ce2 sees? (1 pt)

### B2 (6 points)

On a core router in the `troubleshooting-range` topology:

```text
core1# show ip ospf neighbor
Neighbor ID     Pri State      Dead Time  Address       Interface
10.250.255.2      1 ExStart/-  00:00:33   10.250.0.5    eth2
```

```text
core1# show logging | include OSPF
OSPF: Packet[DD]: Neighbor 10.250.255.2 MTU 9000 larger than [eth2]'s MTU 1500
OSPF: Packet[DD]: Neighbor 10.250.255.2 MTU 9000 larger than [eth2]'s MTU 1500
```

(a) Name the failure and explain the mechanism — which packet carries the value, and why
the adjacency parks at `ExStart` specifically rather than failing earlier or later.
(3 pts)
(b) Give the correct repair and the *masking* repair. Say which is which, and under what
narrow circumstance the masking one is nonetheless the right operational call. (3 pts)

### B3 (6 points)

On r1 in a four-router EIGRP topology (AS 100), after `variance 2` has been configured:

```text
r1# show ip eigrp topology all-links
P 10.0.0.4/32, 1 successors, FD is 3072, serno 4
        via 10.1.12.2 (3072/2816), Ethernet1
        via 10.1.13.2 (5376/5120), Ethernet2
```

```text
r1# show ip route eigrp
D    10.0.0.4/32 [90/3072] via 10.1.12.2, Ethernet1
```

The engineer expected two paths in the routing table and got one. Explain, with the
numbers, why EIGRP refused — and state what would have to change about the *r3 path* for
`variance 2` to install it. Note also why the second path required `all-links` to be
visible at all.

---

## Section 3 — Implementation on paper (25 points)

Write real configuration. Assume interfaces and IP addresses already exist.

### C1 (10 points) — Arista EOS

Write the complete BGP configuration for **isp1** in the `bgp-path-selection` topology:
AS 65100, router-id 10.0.0.2, loopback 10.0.0.2/32.

- eBGP to ce1 at 10.1.11.1 (AS 65001)
- eBGP to ce2 at 10.1.21.2 (AS 65002)
- iBGP to isp2 at 10.1.99.2 (AS 65100)
- advertise its own loopback
- ce2's prefixes, learned by isp1 over eBGP, must be usable by isp2 — solve the next-hop
  problem on the iBGP session

Graded on: correct session definitions, address-family activation, next-hop handling
applied to the right neighbor only, and the `network` statement.

### C2 (8 points) — Arista EOS

Write the OSPF stanza for **r2**, the ABR in the `ospf-nssa` topology, such that:

- area 1 is a **totally** NSSA and area 0 is normal
- r2's loopback 10.0.0.2/32 is in area 0
- the 10.1.12.0/30 link is in area 1 and the 10.1.23.0/30 link is in area 0

Then answer in one line each: which command in your stanza suppresses the Type-3 LSAs,
and which router must *not* have that keyword.

### C3 (7 points) — FRR

An eBGP peer at 198.51.100.1 (AS 64500) sends you routes. Write FRR configuration that:

- accepts **only** 203.0.113.0/24 and its more-specifics down to /28, and nothing else
- sets local-preference 200 on what it accepts
- tags what it accepts with community 65001:100
- leaves the session able to advertise and accept anything at all in the first place —
  name the one line that is required on FRR 8.x for this and say why

Show the prefix-list, the route-map, and the neighbor statements.

---

## Section 4 — Design & trade-offs (15 points)

### D1 (8 points)

Your enterprise is dual-homed to a **single** ISP over two circuits, A (10 Gb) and B
(1 Gb). Requirement: inbound traffic should prefer A; outbound traffic should prefer B
(B is billed differently). Both must fail over automatically.

(a) Name the attribute you use for each direction, where it is configured, and in which
direction it is applied. (4 pts)
(b) Explain why inbound control is fundamentally weaker than outbound control, in terms
of who runs the best-path calculation. (2 pts)
(c) Describe what happens to traffic in each direction when circuit A fails, and what
happens when it returns. Identify one way this design can behave badly on the return.
(2 pts)

### D2 (7 points)

OSPF can only summarise at an ABR or ASBR. EIGRP can summarise on any interface of any
router.

(a) Explain the reason for the OSPF restriction in terms of what the LSDB is and what
would break. (3 pts)
(b) Give one concrete benefit EIGRP's freedom buys you that OSPF cannot match, referring
to query scope. (2 pts)
(c) Give one concrete way EIGRP's freedom lets you break your own network that OSPF's
restriction prevents. (2 pts)

---

## Section 5 — Troubleshooting narrative (10 points)

### E1

**Ticket:** *"Corporate users can't reach the branch office. Branch users say they can
reach the corporate file server just fine. Started this morning."*

Topology is the `troubleshooting-range`: corporate `10.250.10.0/24` behind acc1, branch
`10.250.50.0/24` behind branch1, OSPF area 0 throughout, redundant core1/core2.

Write your response as a structured narrative. You are graded on method, not on guessing
the fault:

1. **Hypothesis.** What does "one direction works, the other doesn't" tell you before you
   run anything? State the class of fault. (2 pts)
2. **First three commands**, in order, with the node you run each on and *what result
   would kill the hypothesis* in each case. (3 pts)
3. **Two candidate causes** consistent with the symptom, ranked, with the discriminating
   piece of evidence that separates them. (2 pts)
4. **Minimal fix** for your top candidate — and state explicitly what you would *not*
   change. (1 pt)
5. **Verification** from the affected user's perspective, not from the router's. (1 pt)
6. **Red flag.** Describe a "fix" for this ticket that would make the symptom disappear
   while leaving the network worse, and say how a reviewer would spot it in your
   transcript. (1 pt)

---

<!-- site-include-end -->

*End of Exam A. Key: [`answer-keys/exam-a-key.md`](answer-keys/exam-a-key.md).*
