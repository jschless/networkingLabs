# Answer Key — OSPF Topic Quiz

**Total:** 30 points

Mechanism earns the marks. Accept equivalent EOS syntax where it would commit and produce
the requested state.

## A1 — Boundaries and route types (3 points)

1. r4's loopback crosses into area 10 in a **Type-3 Inter-Area-Prefix/Summary LSA**
   originated by r2, the ABR. (1)
2. The redistributed prefix is in a **Type-5 AS-External LSA** originated by r4, the
   ASBR. An ABR floods it but does not replace its advertising-router identity. (1)
3. E1 adds the internal OSPF cost to reach the ASBR to the external metric. E2 compares
   the external metric first and normally does not accumulate the internal path cost.
   (1)

**Marking note:** “The ABR summarizes both” is not enough. The distinction between an
ABR-originated Type-3 and an ASBR-originated Type-5 is the target.

## A2 — Adjacency admission (3 points)

1. The E-bit/area-type option in the **Hello packet** disagrees when only one side is
   stub. The peers reject each other's Hellos. (1)
2. The receiver calculates and validates the message digest using the configured key
   material/key ID against the authenticated OSPF packet. A mismatch fails packet
   authentication. (1)
3. Both failures reject packets at or before neighbor admission, so database exchange
   never begins. An MTU mismatch is carried in Database Description packets; Hellos have
   already succeeded, so the peers commonly reach ExStart before rejecting the DBD.
   (1)

Award the authentication point for a clear digest-validation explanation even if the
candidate does not mention the key ID. Do not award it for only “the passwords differ.”

## B1 — A default route that outlived its exit (8 points)

1. `always` tells edge to originate a default even without a local default. It is flooded
   as a Type-5 external LSA and installed on core as `O E2`. (2)
2. The adjacency proves only that the two OSPF speakers can exchange protocol state.
   It does not test edge's upstream data path. Because `always` removes the FIB
   precondition, loss of the upstream default does not cause edge to flush the LSA. (2)
3. Two acceptable policies are:
   - use plain `default-information originate`, which advertises only while a default
     exists in edge's FIB; or
   - use `default-information originate always route-map <MAP>` with the route-map tied
     to a tracked or otherwise trustworthy reachability condition.

   Plain origination is simple but is only as good as the presence of the default route.
   A tracked condition can test farther upstream but adds moving parts and must not match
   an unrelated default. (2)
4. Control-plane evidence: core loses and then correctly relearns the Type-5/default as
   the tracked exit changes, or `show ip ospf database external` and the RIB agree.
   User evidence: a source behind core reaches a known internet destination and the
   return traffic succeeds. One of each is required. (2)

**Misconception:** resetting the OSPF adjacency may temporarily refresh state but does not
change the unconditional origination policy.

## C1 — Multi-area ABR on EOS (6 points)

One complete answer:

```text
router ospf 1
   router-id 10.0.0.2
   passive-interface Loopback0
   area 10 stub
   area 10 range 10.10.0.0/16

interface Loopback0
   ip ospf area 0

interface Ethernet1
   ip ospf area 0
   ip ospf authentication message-digest
   ip ospf message-digest-key 7 md5 BACKBONE

interface Ethernet2
   ip ospf area 10
```

Point allocation:

- process and router ID: 1
- correct area membership on all three interfaces: 1.5
- passive loopback: 0.5
- stub declaration: 1
- area-range command names the source area and correct prefix: 1
- both message-digest commands with key ID and secret: 1

The internal area-10 router must also be configured as stub for a real adjacency, but the
question explicitly asks only for r2.

## C2 — OSPFv3 on EOS (4 points)

```text
interface Ethernet1
   ipv6 ospf6 area 0

interface Loopback0
   ipv6 ospf6 area 0
   ipv6 ospf6 passive

router ospf6
   ospf6 router-id 10.0.0.6
```

- both interfaces enrolled in area 0: 1.5
- loopback passive at the interface: 1
- `router ospf6` process: 0.5
- explicit 32-bit router ID: 1

Do not award full credit for OSPFv2 `network` statements. OSPFv3 area enrollment in these
labs is per-interface.

## D1 — The impossible transit area (6 points)

1. A virtual link logically extends area 0 between two ABRs across a **regular transit
   area**. A stub or NSSA cannot be the transit area, so area 20 is ineligible. Area 30
   also violates the normal rule that every non-backbone area must connect to area 0.
   (2)
2. A defensible temporary repair is to convert area 20 to a normal area on every attached
   router, then configure matching `area 20 virtual-link <peer-router-id>` statements on
   the ABRs. That conversion must be coordinated: an area-type mismatch drops
   adjacencies, and removing NSSA changes how its external routes are represented.
   A GRE or other temporary area-0 path can also earn credit if its operational
   implications are addressed. The preferred design is a real, resilient area-0
   connection or an area redesign that attaches b1 directly to the backbone. (2)
3. Evidence should include two of:
   - the virtual link is Full and shown as an area-0 adjacency;
   - area-30 prefixes appear as Type-3/inter-area routes on the backbone side;
   - area-0 prefixes appear as `O IA` behind area 30;
   - an end host behind area 30 reaches an area-0 destination with return traffic.

   At least one item must prove route propagation or end-to-end forwarding. (2)

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1 | ABR/ASBR roles, Type-3 and Type-5, E1/E2 | `ospf-multiarea`, `ospf-summarization`, `ospf-bgp-redist` |
| A2 | Hello admission, area options, authentication, DBD MTU stage | `ospf-auth`, `debug-ospf-auth`, `debug-ospf-multiarea` |
| B1 | Conditional default origination and upstream failure | `ospf-default-route` |
| C1 | Multi-area configuration, stub areas, summarization, authentication | `ospf-multiarea`, `ospf-summarization`, `ospf-auth` |
| C2 | OSPFv3 process, interface enrollment, link-local forwarding | `ipv6-ospf3` |
| D1 | Backbone continuity and virtual-link constraints | `ospf-virtual-link`, `ospf-nssa` |
