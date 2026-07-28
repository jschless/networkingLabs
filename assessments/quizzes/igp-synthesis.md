# Synthesis Quiz — Interior Gateway Protocols

**Time:** 50 minutes · **Total:** 40 points · **Closed book, no CLI**

**Prerequisites:** the OSPF, EIGRP, and IS-IS topic quizzes.

This quiz does not repeat protocol trivia from the individual quizzes. It tests comparison,
protocol selection, redistribution boundaries, and troubleshooting when IGPs interact.
Configuration in Section 3 is vendor-neutral policy pseudocode unless stated otherwise.

---

## Section 1 — Comparative mechanisms (8 points)

### A1 — Three ways to describe a network (4 points)

Compare what OSPF, EIGRP, and IS-IS exchange and the computation each uses to select
loop-free routes. Include the protocol's main unit of exchanged state and the role of
SPF or DUAL.

### A2 — Alternate paths are not equivalent (4 points)

A destination has one best path and one higher-cost path.

For each protocol, explain whether and how the higher-cost path can be used before the
best path fails:

- OSPF
- EIGRP
- IS-IS

Distinguish unequal-cost forwarding from a precomputed backup or a fresh SPF calculation.

---

## Section 2 — Evidence at a redistribution boundary (10 points)

### B1 — The route came home

`10.50.0.0/16` originates in the EIGRP domain. br1 and br2 both connect that domain to
an OSPF core and both perform mutual redistribution. After br2 loses its direct EIGRP
path toward the origin, these views are captured:

```text
br1# show ip route 10.50.0.0/16
D     10.50.0.0/16 [90/2816] via 10.1.1.2, Ethernet1

br2# show ip route 10.50.0.0/16
O E2  10.50.0.0/16 [110/20] via 10.0.12.1, Ethernet2, tag 200

br2# show route-map OSPF-TO-EIGRP
route-map OSPF-TO-EIGRP permit 10
  set metric 10000 100 255 1 1500

branch-core# show ip route 10.50.0.0/16
D EX  10.50.0.0/16 [170/2560512] via 10.1.2.1, Ethernet2
```

1. Reconstruct the path by which the EIGRP-originated route became `D EX` in its home
   domain. (3 pts)
2. What control failure is visible in the route-map, and what loop or suboptimal-routing
   risk does it create? (2 pts)
3. State the exact tag policy br2 should apply before redistributing OSPF into EIGRP.
   (2 pts)
4. Why are administrative distance and the supplied seed metric not sufficient
   loop-prevention mechanisms? (2 pts)
5. Name one check that proves the route is no longer being reintroduced. (1 pt)

---

## Section 3 — Selection and policy (12 points)

### C1 — Select for the requirements (6 points)

Choose OSPF, EIGRP, or IS-IS for each case and justify the choice with two requirements,
not with familiarity or vendor preference. A different choice can earn full credit when
the reasoning satisfies the constraints.

1. A multivendor enterprise needs an open-standard IPv4/IPv6 IGP, clear area boundaries,
   and broad operational familiarity. (2 pts)
2. A single-platform hub-and-spoke WAN wants unequal-cost use of dissimilar circuits and
   explicit query containment at hundreds of spokes. (2 pts)
3. A service-provider core expects to carry SR-MPLS information in an extensible TLV
   system and wants the IP control plane independent of interface IP addressing. (2 pts)

### C2 — Write the boundary policy (6 points)

Two routers mutually redistribute between an OSPF domain and an EIGRP domain.
Write vendor-neutral route-policy pseudocode for both directions that:

- tags routes originating in EIGRP with 200 when they enter OSPF;
- tags routes originating in OSPF with 100 when they enter EIGRP;
- prevents either class from being redistributed back into its source domain;
- permits only approved prefixes and denies everything else;
- assigns an explicit EIGRP seed metric.

---

## Section 4 — Troubleshooting narrative (10 points)

### D1 — Both adjacencies are healthy

An acquired branch network runs EIGRP. The existing campus core runs OSPF. br1 and br2
perform mutual redistribution for redundancy. After br1's EIGRP-facing circuit fails,
branch-initiated sessions to the data center still work, but some data-center-initiated
sessions loop between br1 and br2. Both OSPF adjacencies and br2's EIGRP adjacency are
healthy.

Write a structured response:

1. State the leading fault class and one plausible alternative that also fits the
   direction-dependent symptom. (2 pts)
2. Give four ordered pieces of evidence, collected across both routing domains, and say
   what each proves or disproves. At least one must inspect route tags or protocol origin,
   and at least one must inspect forwarding rather than only the RIB. (4 pts)
3. Describe the minimal safe policy repair. (2 pts)
4. Give an end-to-end verification that exercises both initiation directions. (1 pt)
5. Name one symptom-masking change that should be rejected and explain why. (1 pt)

---

<!-- site-include-end -->

*End of IGP Synthesis quiz. Key:
[`../answer-keys/quizzes/igp-synthesis-key.md`](../answer-keys/quizzes/igp-synthesis-key.md).*
