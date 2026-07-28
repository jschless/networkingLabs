# Topic Quiz — BGP Policy & Security

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `bgp-filtering`, `bgp-communities`, `bgp-aggregation`,
`bgp-prefix-security`, `bgp-rpki`, and `internet-peering-ixp`.

Questions use EOS syntax unless they explicitly ask for policy rather than commands.

---

## Section 1 — Mechanisms (6 points)

### A1 — The forwarding table gets the last word (3 points)

An attacker announces `192.0.2.128/25` while the legitimate origin continues announcing
`192.0.2.0/24`. Explain why BGP attributes on the /24 cannot make traffic for
`192.0.2.200` prefer it over the /25. Then explain why a maximum-prefix limit is not a
specific defense against this attack. (3 pts)

### A2 — What RPKI proves (3 points)

A ROA authorizes AS 65010 to originate `198.51.100.0/24` with maximum length /24.
Classify these routes as valid, invalid, or not found, and give the reason:

1. `198.51.100.0/24`, origin AS 65010
2. `198.51.100.0/25`, origin AS 65010
3. `203.0.113.0/24`, origin AS 65010

Then state one path-security property that RPKI does not prove.

---

## Section 2 — Evidence reading (8 points)

### B1 — Established, valid, and still rejected

A customer has added authorized prefix `203.0.114.0/24`. The peering session remains
Established, and the local RTR cache marks the route valid.

```text
edge# show bgp ipv4 unicast neighbors 198.18.0.2 received-routes
 *> 203.0.113.0/24  198.18.0.2  0 65020 i  RPKI valid
 *> 203.0.114.0/24  198.18.0.2  0 65020 i  RPKI valid

edge# show bgp ipv4 unicast
 *> 203.0.113.0/24  198.18.0.2  0 65020 i

edge# show ip prefix-list IRR-AS65020
seq 5 permit 203.0.113.0/24

edge# show running-config section router bgp
router bgp 65000
   address-family ipv4
      neighbor 198.18.0.2 prefix-list IRR-AS65020 in
```

1. Localize the failure and explain why session state and RPKI validity do not imply
   acceptance into the local BGP table. (3 pts)
2. Describe the smallest source-to-policy repair if the prefix-list is generated from a
   local IRR object. (2 pts)
3. State the soft operational action needed after changing inbound policy. (1 pt)
4. Give two checks proving the new prefix was admitted without admitting an unrelated
   prefix. (2 pts)

---

## Section 3 — Application (10 points)

### C1 — Customer import policy (6 points)

Customer AS 65110 may advertise exactly `203.0.112.0/23` and its /24 more-specifics, but
nothing longer or outside that block. On accepted routes, set local preference 150 and
add community `65000:110` without deleting an existing community.

Write the EOS prefix-list, route-map, and inbound neighbor attachment for peer
`192.0.2.2`. Assume the neighbor is already defined and activated.

### C2 — Aggregate without hiding contributor origin (4 points)

Router `agg` has component routes inside `10.16.0.0/21`. Write the EOS address-family
command that advertises only the /21 aggregate while retaining contributor AS
information. Then state:

1. what causes the aggregate to exist or be withdrawn; and
2. one operational trade-off of suppressing every component.

---

## Section 4 — Design and troubleshooting (6 points)

### D1 — A constrained RTBH service

At an IXP, participants request remote-triggered blackholing by attaching community
`65010:666` to a host route. Design four controls that let a participant blackhole an
authorized `/32` during an incident without turning the community into a way to discard
someone else's traffic. Include how the exception is removed and audited. (6 pts)

---

<!-- site-include-end -->

*End of BGP Policy & Security quiz. Key:
[`../answer-keys/quizzes/bgp-policy-security-key.md`](../answer-keys/quizzes/bgp-policy-security-key.md).*
