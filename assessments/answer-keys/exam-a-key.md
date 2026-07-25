# Exam A — Answer Key & Grading Notes

Grader's rule of thumb: a candidate who names the mechanism but fumbles the command name
is in better shape than one who recites the command and cannot say what it does. Award
accordingly. Where a question asks "why", an answer with no causal claim in it scores at
most half regardless of accuracy.

---

## Section 1 — Concepts & mechanisms (30)

**A1 (3).**
(a) Type-7 LSAs never leave the NSSA. The NSSA ABR (r2) **re-originates** — translates —
the Type-7 into a brand-new Type-5 and floods that into the rest of the domain, so the
advertising router is now r2's ID (10.0.0.2). r3 cannot tell an NSSA was ever involved.
(b) Type-7 (NSSA-external), visible with `show ip ospf database nssa-external`, carrying
the Forward Address 192.168.100.1.
(c) The P-bit ("propagate") is set by the originating ASBR (r1) and is what *permits* the
ABR to translate. Clear P-bit means do not translate — used to stop a route leaking back
out when the NSSA has multiple ABRs.

*1 point each. Deduct if the candidate says the Type-5 is "forwarded" or "flooded through"
rather than re-originated — that is the misconception the question exists to catch.*

**A2 (3).** The N/E **option bits in the OSPF hello packet**. Hellos with mismatched area
type are discarded, so the neighbor never appears in the neighbor table at all — this
fails before any state machine progress, which is why there is no stuck `ExStart` or
`2-Way` to look at. Same signature: stub/normal mismatch (same bits), mismatched area ID,
mismatched hello/dead intervals, mismatched authentication, or mismatched
subnet/mask on the link.

*2 for the option bits in hellos, 1 for a valid second example. Naming MTU mismatch as
the second example is **wrong** — that one does progress to ExStart, which the question
explicitly excludes.*

**A3 (3).** `area 1 nssa no-summary`, on the **ABR only** (r2). The default appears on r1
as **`O N2 0.0.0.0/0`** — the ABR originates it through the NSSA mechanism as a Type-7,
not as a Type-3 summary (`O IA`) and not as a Type-5 external (`O E2`), because Type-5 is
forbidden inside an NSSA by definition.

*1 for the keyword, 1 for "ABR only", 1 for `O N2` with a reason.*

**A4 (3).** FD = the lowest metric this router has ever computed to the destination since
the last transition to passive; RD (reported/advertised distance) = the metric the
neighbor advertises for that destination, i.e. the neighbor's own cost to it. Feasibility
condition: **RD < FD** (strictly less than). EIGRP enforces it because it is the only
local test that proves the neighbor is not routing back through *you* — a neighbor whose
own cost is already lower than your best cost cannot have you on its path. Variance is a
metric-range filter and proves nothing about loop-freedom.

*Accept "advertised distance". Deduct 1 if the inequality is written `≤`.*

**A5 (3).** The walk falls all the way through to **rule 9, oldest eBGP path**, and if
even that ties, **rule 10, lowest router-ID** (isp1, 10.0.0.2). Dangerous because "oldest
session" is a function of boot order and session flaps, not of design: a maintenance
window or a single flap silently relocates all outbound traffic to the other ISP, with no
configuration change to point at during the post-mortem and nothing in the config that
documents the intent.

*2 for naming both tiebreakers, 1 for the instability/non-determinism argument. "It's
arbitrary" alone scores 1.*

**A6 (3).**
(a) Weight is Arista/Cisco-proprietary and **strictly local to the router** — it is never
encoded in an UPDATE, so isp2 never learns it and its own best-path walk is unaffected.
(b) Inbound traffic to ce1 is chosen by *isp1 and isp2's* best-path calculations, which
weight cannot touch. To influence it, advertise differently outbound: **AS-path
prepending** (or MED, or a community the ISP publishes). The limitation: it is a hint,
not a control — the receiving AS applies local-preference first, which outranks both
AS-path and MED, so it can override you at will.

*1 + 1 + 1. Answering "use local-preference" for (b) is wrong and scores 0 for that
part — LP is never sent to an eBGP peer.*

**A7 (3).** `49.0001` = AFI (49, private) + area ID; `0000.0000.0002` = system ID
(6 bytes, unique per router); `00` = NSEL, always 00 for a router.
Behavioural differences from the OSPF DR, any two of:
- The DIS is **preemptive** — a higher-priority router arriving later takes over
  immediately; the OSPF DR is not, it keeps the role until it dies.
- There is **no backup DIS**; OSPF has a BDR.
- The DIS creates a **pseudonode LSP** on behalf of the LAN and floods periodic **CSNPs**
  as the reliability mechanism; OSPF's DR relays LSAs and uses per-neighbor
  acknowledgement instead.
- DIS ties break on highest **SNPA/MAC**, DR ties on highest router-ID.

*1 for the NET breakdown, 1 per behavioural difference up to 2.*

**A8 (3).** On redistribution from protocol X into protocol Y, **set a route tag** on the
injected routes. At every redistribution point going the other way (Y into X), a route-map
**denies any route carrying that tag**. The tag survives redistribution and is carried in
the LSA/update, so a route that originated in X and travelled through Y is recognisable
and refused re-entry. This kills the feedback loop at every mutual redistribution point
without needing to enumerate prefixes, which is why it scales where prefix-lists do not.

*2 for the tag-and-deny mechanism, 1 for why it beats prefix filtering. Mentioning AD
manipulation as a complementary control earns back a lost point.*

**A9 (3).** **RFC 8212** — "Default External BGP (EBGP) Route Propagation Behavior without
Policies". Without the switch and without an explicit inbound/outbound policy, the session
**establishes normally and then advertises and accepts nothing**. It is easy to
misdiagnose because `show bgp summary` shows the neighbor `Established` with a state/pfx
count of 0 — which looks exactly like a peer that simply has nothing to send, so the
engineer goes hunting for missing `network` statements on the far side instead of looking
at local policy.

*1 for the RFC or its behaviour, 1 for "session up, zero prefixes", 1 for the
misdiagnosis. Accept "it's default-deny for eBGP without policy" in place of the RFC
number.*

**A10 (3).**
- **PortFast** — on **edge/access ports facing hosts**. Skips listening and learning so
  the port forwards immediately; protects against DHCP timeouts and slow boot, not
  against an attack.
- **BPDU Guard** — on the same **edge/access ports**, as PortFast's safety catch. Protects
  against someone plugging a switch into a user port and altering the topology.
- **Root Guard** — on ports facing **other switches** (downstream or peer), where you
  expect BPDUs but do not accept a new root. Protects the position of the root bridge.

Outcomes are deliberately different: a BPDU Guard port receiving **any** BPDU is
**err-disabled** (shut down, requires recovery/manual clear). A Root Guard port receiving a
**superior** BPDU goes to **root-inconsistent** (blocking) and **recovers by itself** as
soon as the superior BPDUs stop.

*2 for the three roles/placements, 1 for the err-disable vs self-recovering
root-inconsistent distinction. The self-recovery point is the discriminator — do not award
it for "the port blocks".*

---

## Section 2 — Evidence reading (20)

### B1 (8)

(a) **Rule 4, AS-path length** — 2 ASNs (`65100 65002`) versus 4
(`65100 65100 65100 65002`). Rules 1–3 are identical: both weight 0, both localpref 100,
neither locally originated. The walk stops at 4 and never reaches origin, MED, or the
tiebreakers. *(2)*

(b) Somebody **prepended AS 65100 twice**, on **isp1**, **outbound toward ce1** — the
extra ASNs are 65100's own, and they only appear on the copy ce1 received from isp1. This
is the ISP steering ce1's *outbound* traffic onto isp2. *(3 — 1 for "AS-path prepend",
1 for isp1, 1 for outbound/toward-ce1. A candidate who says ce2 prepended loses the
second point: prepending at ce2 would have lengthened **both** paths equally.)*

(c) **Yes, the best path moves to 10.1.11.2.** Weight is **rule 1** and is evaluated
before AS-path at rule 4, so a longer AS path is irrelevant once weight differs. This is
exactly why weight is described as a sledgehammer. *(2)*

(d) **No.** Weight is local to ce1 and never advertised, so ce2's table and best-path
choice are untouched. (ce2 independently decides its own return path either way.) *(1)*

### B2 (6)

(a) **OSPF MTU mismatch.** The interface MTU is carried in the **Database Description
(DBD) packet**. A router that receives a DBD advertising an MTU **larger than its own
interface MTU** silently discards it. The exchange therefore never gets past
master/slave negotiation and DBD retransmission, so the adjacency parks at **`ExStart`**
(sometimes `Exchange`) and retries forever. It cannot fail earlier because hellos carry no
MTU and match fine — the neighbor is discovered normally — and it cannot get further
because the LSDB exchange is the step that is blocked. *(3 — 1 for naming it, 1 for "MTU
is in the DBD", 1 for why the state is specifically ExStart.)*

(b) **Correct repair:** make the two interface MTUs match — set eth2 on the far router
back to 1500, or raise core1's to 9000, depending on which value the design calls for.
**Masking repair:** `ip ospf mtu-ignore` on one or both sides, which skips the check and
lets the adjacency come up over a genuine MTU mismatch — large LSAs and large data
packets will then be dropped or fragmented downstream, converting a loud failure into a
quiet one.

The narrow case where mtu-ignore is correct: when the MTU values are *reported*
differently but the real forwarding MTU matches — a vendor interop quirk where one
platform counts the L2 header in its MTU and the other does not. There, the check is
producing a false positive and ignoring it is right. *(3 — 1 correct, 1 masking, 1 for a
defensible narrow case. "Never correct" scores 0 for the third point; the question asks
for the exception and one exists.)*

### B3 (6)

The r3 path fails the **feasibility condition**, and variance cannot override it.

- FD via the successor is **3072**.
- The r3 path's **RD is 5120**.
- FC requires **RD < FD** → `5120 < 3072` is **false**, so the r3 path is not a feasible
  successor.
- The variance test would have passed on its own: `variance 2` allows metrics up to
  `2 × 3072 = 6144`, and the path's metric is 5376 ≤ 6144. Passing the variance test is
  necessary but not sufficient — FC is checked first and is not negotiable.

**What would have to change:** the **reported** distance must drop below 3072, and RD is
r3's own cost to 10.0.0.4/32 — so the change must be on the **far side**, e.g. improving
the r3–r4 link (higher bandwidth / lower delay) so r3 advertises a lower RD. A candidate
who proposes raising the bandwidth on the *r1–r3* link has fallen into the trap: that
lowers the composite metric 5376 but leaves RD at 5120 untouched, so the path stays
infeasible. (Also technically true and worth credit: if the successor path *degraded* so
that FD rose above 5120, the r3 path would become feasible — the right answer for the
wrong reason operationally.)

**Why `all-links` was needed:** `show ip eigrp topology` lists only successors and
feasible successors. A path that fails FC is held but not shown; `all-links` is what
reveals it.

*3 for the FC arithmetic, 2 for locating the required change on the far side (1 only if
they say "improve the metric" without noticing RD is remote), 1 for the `all-links`
explanation.*

---

## Section 3 — Implementation on paper (25)

### C1 (10) — isp1, Arista EOS

```text
router bgp 65100
   bgp router-id 10.0.0.2
   neighbor 10.1.11.1 remote-as 65001
   neighbor 10.1.21.2 remote-as 65002
   neighbor 10.1.99.2 remote-as 65100
   !
   address-family ipv4
      neighbor 10.1.11.1 activate
      neighbor 10.1.21.2 activate
      neighbor 10.1.99.2 activate
      neighbor 10.1.99.2 next-hop-self
      network 10.0.0.2/32
```

Scoring:
- 2 — three `remote-as` statements with the correct ASNs (65001 / 65002 / 65100)
- 2 — `bgp router-id 10.0.0.2`
- 2 — all three neighbors `activate`d under `address-family ipv4`
- 3 — **`next-hop-self` on 10.1.99.2 only**. This is the graded idea: eBGP-learned routes
  passed to an iBGP peer keep the external next-hop, which isp2 has no route to. Applying
  it to an eBGP neighbor as well is not fatal but shows the candidate does not know why
  the command exists — cap at 2.
- 1 — `network 10.0.0.2/32`

Accept `neighbor X send-community`, descriptions, and `maximum-paths` as harmless extras.
An answer that solves the next-hop problem with a route-map `set ip next-hop` on the iBGP
session, or by running the transit link in the IGP and advertising it, earns full marks
for that item if the reasoning is stated.

### C2 (8) — r2, the NSSA ABR

```text
router ospf 1
   router-id 10.0.0.2
   network 10.0.0.2/32 area 0
   network 10.1.12.0/30 area 1
   network 10.1.23.0/30 area 0
   area 1 nssa no-summary
```

Scoring: 2 for the three `network`/area assignments being correct (loopback and
10.1.23.0/30 in area 0, 10.1.12.0/30 in area 1), 2 for `router-id`, 4 for
`area 1 nssa no-summary`. Accept `router ospf` without a process ID — the lab README's
solution blocks are written that way.

One-liners: **`area 1 nssa no-summary`** is what suppresses the Type-3 LSAs; the
`no-summary` keyword must **not** appear on **r1** (or any non-ABR) — r1 keeps plain
`area 1 nssa`. A candidate who says r1 needs no NSSA configuration at all is wrong: the
`nssa` part is required on every router in the area, only `no-summary` is ABR-only.

### C3 (7) — FRR inbound policy

```text
ip prefix-list CUST-IN seq 5 permit 203.0.113.0/24 le 28
!
route-map CUST-IN permit 10
 match ip address prefix-list CUST-IN
 set local-preference 200
 set community 65001:100
!
router bgp 65001
 no bgp ebgp-requires-policy
 neighbor 198.51.100.1 remote-as 64500
 !
 address-family ipv4 unicast
  neighbor 198.51.100.1 activate
  neighbor 198.51.100.1 route-map CUST-IN in
 exit-address-family
```

Scoring:
- 2 — `le 28` on the prefix-list. `ge 24 le 28` also correct; a bare
  `permit 203.0.113.0/24` scores 0 for this item (matches the /24 only, not the
  more-specifics), and `le 32` scores 1 (over-permissive).
- 1 — `set local-preference 200`
- 1 — `set community 65001:100`
- 1 — the route-map's **implicit deny** at the end is what drops everything else. Award
  this if the candidate states it, or if they wrote an explicit `route-map CUST-IN deny 20`.
- 2 — **`no bgp ebgp-requires-policy`**, with the reason: FRR 8.x implements RFC 8212, so
  without it the session comes up and moves no prefixes in either direction regardless of
  the route-map. Award full marks to a candidate who instead supplies **both** an inbound
  and an outbound route-map and explains that satisfying the policy requirement in each
  direction is the alternative to disabling the check — that is the more correct answer
  operationally.

Common miss: applying the route-map with `route-map CUST-IN out`. Zero for that item.

---

## Section 4 — Design & trade-offs (15)

### D1 (8)

(a) *(4)*
- **Inbound prefer A:** influence what the ISP sends you, on **your edge, outbound toward
  the ISP**. With a single ISP, **MED** is the natural tool (lower MED on A, higher on B —
  MED is comparable because both paths come from the same AS). **AS-path prepending** on
  B's outbound advertisements is the blunter, always-works alternative. A community the
  ISP publishes for local-pref control is the best answer if the ISP offers one.
- **Outbound prefer B:** **local-preference**, set **inbound** on the routes learned from
  B (e.g. LP 200 on B, default 100 on A), applied on your edge routers. **Weight** works
  if only one router makes the decision, but does not propagate to the rest of your AS —
  say so.

*2 per direction. Naming the attribute without the direction it is applied in scores 1.*

(b) *(2)* Because the best-path calculation for traffic coming *toward* you runs on
**routers you do not administer**. Everything you send outbound — AS-path length, MED,
origin — sits at rules 4–6, *below* the ISP's own local-preference at rule 2. Any policy
the ISP applies for its own commercial reasons silently outranks every hint you can send.
Outbound, you own the decision outright.

(c) *(2)* A fails: inbound converges to B automatically once the A path is withdrawn (it
was already in the table, just less preferred). Outbound was already on B and does not
move. A returns: the ISP relearns the better-MED/shorter path and inbound shifts back —
possibly repeatedly if A is flapping, which is what dampening exists for.

The bad behaviour worth naming: **this design is deliberately asymmetric** (in on A, out
on B). Any stateful device in the path — firewall, NAT, load balancer, or a router doing
**strict uRPF** — sees only one half of each flow and will drop it. Award the 2 points
for identifying asymmetry as the risk even if the candidate does not name flapping.

### D2 (7)

(a) *(3)* Every router in an OSPF area must hold an **identical LSDB** and independently
run SPF over it; that identity is the invariant the protocol's loop-freedom rests on. If
an internal router suppressed component LSAs and injected an aggregate, routers in the
same area would compute SPF over **different databases** and could form loops. Summaries
are therefore only legal where a database boundary already exists — at the **ABR**
(Type-3) and the **ASBR** (Type-5/7). Inside an area, topology cannot be hidden at all.

(b) *(2)* EIGRP is distance-vector with no area database to hold consistent, so a summary
can go on any interface — and a summary point **bounds the query domain**: it answers
queries for anything inside the summary authoritatively instead of propagating them.
That directly reduces stuck-in-active risk and shrinks the blast radius of a flapping
prefix. OSPF has no equivalent, because a flap inside an area is flooded to the whole area
regardless.

(c) *(2)* The freedom to summarise anywhere is the freedom to advertise a block you cannot
fully reach: summarise 10.1.0.0/16 on a router that only holds half of it and you attract
traffic for the other half and drop it on the local Null0 discard route. Discontiguous
components make this trivially easy to do by accident. OSPF's restriction means only two
well-defined router roles can make that mistake, and both are places an engineer is
already thinking about aggregation.

---

## Section 5 — Troubleshooting narrative (10)

### E1 — model answer

**1. Hypothesis (2).** One direction working and the other failing rules out the whole
class of "the branch is down" faults — L1, the branch's OSPF adjacency, and the branch
prefix's existence in the IGP are all provably fine, because branch→services traffic is
completing *and getting replies*. The fault class is therefore **path-specific**: the
corporate→branch direction is taking a different path from the branch→corporate
direction, and something on that one path is broken or filtering. Suspect route
preference / metric drift, or a directional filter.

*2 for reasoning from the working direction to eliminate fault classes. A candidate who
starts with "check if branch1 is up" has not read the ticket — 0.*

**2. First three commands (3).** Any disciplined ordered set; this is one:

| # | Node | Command | What would kill the hypothesis |
|---|---|---|---|
| 1 | corporate client | `traceroute 10.250.50.10` | Dying at the first hop → gateway/access-layer fault, not a path fault; re-scope to acc1 |
| 2 | core1 **and** core2 | `show ip route 10.250.50.0/24` | Both cores showing the same, sane next-hop → path preference is fine, move to filtering |
| 3 | branch1 | `show ip route 10.250.10.0/24` | A correct route present with a sane metric → forwarding is fine both ways, fault is above L3 |

*1 per command that has a node and a stated falsifier. A command with no falsifier scores
0.5 — the falsifier is the graded part.*

**3. Two candidate causes, ranked (2).**
1. **OSPF metric / cost change** on a core-to-branch transit interface, so corporate
   traffic now prefers a path that is broken or filtered downstream, while branch return
   traffic still takes the original good path.
2. **A directional ACL** on the branch-facing interface that permits the services subnet
   but not `10.250.10.0/24`.

**Discriminator:** the traceroute from a corporate host. If packets **reach branch1 and
stop there**, it is filtering. If they die **on the core→branch transit**, it is path
preference. *(1 for two plausible ranked causes, 1 for a discriminator that actually
separates them.)*

**4. Minimal fix (1).** Restore the changed OSPF cost on the single interface that
changed — nothing else. Explicitly **not** changed: no static route to force the traffic,
no OSPF process restart, no ACL widened to `permit ip any any`, no timer adjustments.

**5. Verification (1).** From the corporate client, not the router: ping and open the
actual application (HTTP to the branch host) from `10.250.10.10`, and re-run traceroute to
confirm the path now matches the design. Confirm the branch direction still works — a fix
that repairs one direction and breaks the other is a common own goal. `show ip route`
looking right on core1 is **not** verification.

**6. Red flag (1).** Adding a static route on core1 for `10.250.50.0/24` pointing at the
working next-hop. The symptom vanishes instantly, the wrong OSPF cost stays wrong, and an
undocumented static now silently outranks the IGP for that prefix — it will survive the
real repair and cause a second incident later.

A reviewer spots it in the transcript by ordering: the configuration change appears
**before** any command that gathered evidence for it, and the diagnosed cause in the
write-up does not match the object that was modified. Under the range's rubric this takes
the red-flag cap regardless of the ticket verifying green.

---

## Remediation table

Lost more than half the points on a question? Re-run the lab.

| Question | Topic | Lab |
|---|---|---|
| A1, A2, A3, C2 | NSSA, Type-7 translation, area-type option bits | `labs/ospf-nssa`, `labs/debug-ospf-nssa` |
| A4, B3 | EIGRP feasibility condition, variance | `labs/eigrp-variance`, `labs/eigrp-basics` |
| A5, A6, B1, C1 | BGP path selection, weight vs LP vs prepend | `labs/bgp-path-selection`, `labs/bgp-basics`, `labs/debug-bgp-path-selection` |
| A7 | IS-IS NET, DIS behaviour | `labs/isis-basics`, `labs/isis-multiarea` |
| A8, D2 | Redistribution loops, tags, summarisation | `labs/redistribution-tags`, `labs/ospf-summarization`, `labs/ospf-bgp-redist` |
| A9, C3 | RFC 8212, prefix-lists, route-maps | `labs/bgp-filtering`, `labs/bgp-communities`, `labs/debug-bgp-filtering` |
| A10 | Edge hardening, STP protections | `labs/campus-l2-hardening`, `labs/stp-operations` |
| B2 | OSPF MTU / adjacency states | `labs/debug-ospf-multiarea`, `labs/troubleshooting-range` (T2 MTU ticket) |
| D1 | Dual-homed BGP traffic engineering | `labs/enterprise-wan-edge`, `labs/enterprise-wan-edge-capstone` |
| E1 | Structured troubleshooting method | `labs/troubleshooting-range`, then any `labs/debug-*` |
