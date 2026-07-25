# Exam B — Answer Key & Grading Notes

This exam separates candidates who configured the labs from candidates who understood
them. The recurring theme in Sections 2 and 5 is the same one: **a healthy control plane
is not a healthy forwarding plane.** Grade hard on that distinction wherever it appears.

---

## Section 1 — Concepts & mechanisms (30)

**B1 (3).**
(a) The label is the **SRGB base plus the index**: FRR's default SRGB is 16000–23999, so
index 2 → **16000 + 2 = 16002**. The index — not the label — is what IS-IS floods, which
is why every router in the domain derives the same label for pe1 without any signalling
between them.
(b) SR removes **LDP** (a second protocol, with its own sessions, timers and failure modes)
and the **per-node label state / LDP-IGP synchronisation problem** that comes with it.
Labels are instead distributed **inside the IGP itself** — IS-IS carries prefix-SIDs as
sub-TLVs in the LSP.

*2 for the arithmetic including the SRGB base, 1 for "labels ride in the IGP". A candidate
who says the label is configured directly has missed the point of the index — 0 for (a).*

**B2 (3).** The signal is the **implicit-null label, value 3**, advertised by the egress
router. The **penultimate** router (the second-to-last hop) pops the transport label and
forwards a plain IP packet — or, in a VPN, a packet with only the VPN label left. This
saves the egress router a **double lookup**: without PHP it would have to pop the transport
label and *then* do a second lookup to forward, which was expensive on older hardware.

What PHP complicates: the egress router **loses the label's QoS/EXP bits and the ability to
account for or classify traffic on the transport label**, and MPLS traceroute/OAM gets less
informative at the last hop. In an L3VPN the VPN label must survive, which is exactly why
the stack is two deep.

*1 for label 3, 1 for the penultimate router doing the pop and why, 1 for a real
downside.*

**B3 (3).**
- **RD (route distinguisher):** makes the prefix **unique** in the VPNv4 table. It is
  prepended to the IPv4 prefix so that 10.1.1.0/24 in customer A and the same prefix in
  customer B are two distinct VPNv4 NLRI and BGP does not treat them as competing paths for
  one destination. It carries **no policy meaning whatsoever**.
- **RT (route target):** an **extended community** attached to the route that drives
  **import and export policy** — which VRFs on which PEs accept the route.

**Yes, the VPN still works with different RDs**, provided the RTs match. Import is decided
entirely by RT. Per-PE unique RDs are in fact common practice — they keep paths from
different PEs distinct so a route reflector can carry and reflect both instead of choosing
one best path, which is what you want for multihomed sites.

*1 RD, 1 RT, 1 for the "yes, RTs decide" answer with a reason. A candidate who says the VPN
breaks scores 0 for the third part — this is the misconception the question targets.*

**B4 (3).** Two labels:
- **Transport / IGP label** (outer) — here the SR node-SID of pe2, **16003**. Derived from
  pe2's advertised prefix-SID index; *every* router computes it, so nobody "assigns" it in
  a signalling sense — but the imposing router is pe1.
- **VPN / service label** (inner) — **assigned by the egress PE, pe2**, advertised to pe1
  in the BGP VPNv4 update (`label vpn export auto` is what allocates it). It identifies the
  VRF / customer next-hop at pe2.

At the **penultimate P router**: PHP pops the transport label, forwarding to pe2 a packet
carrying only the VPN label. At the **egress PE (pe2)**: pops the VPN label, uses it to
select VRF `CUST-A`, and does an IP lookup **in that VRF** to forward to ce2.

*1 for naming both labels correctly, 1 for "the egress PE assigns the VPN label", 1 for the
two-stage disposition. Getting the inner/outer order backwards costs 1.*

**B5 (3).**
- **Type-2 (MAC/IP advertisement)** — a host's MAC, optionally with its IP. Missing → no
  unicast reachability learned via the control plane; the fabric falls back to flooding, or
  simply does not forward. Also carries the L3VNI for symmetric IRB.
- **Type-3 (Inclusive Multicast Ethernet Tag / IMET)** — how VTEPs discover each other for
  a given VNI and build the BUM flood list. Missing → no ARP/broadcast/unknown-unicast
  replication; hosts never ARP each other successfully even though unicast plumbing exists.
- **Type-5 (IP Prefix route)** — a routed prefix rather than a host, used for
  prefix-based/external routes and silent hosts. Missing → no reachability to subnets that
  are not represented by a learned MAC (external routes, other pods, summarised prefixes).

**Symmetric vs asymmetric IRB:** asymmetric routes on ingress into the destination VNI, so
**every leaf must have every VNI and every subnet configured**. Symmetric routes into a
shared **L3VNI** (a transit VNI per VRF), so a leaf only needs the VNIs of the subnets it
actually hosts — it scales.

The `vxlan-evpn` lab builds **symmetric IRB**, and you can tell from the config: the
presence of an **L3VNI per VRF** (`vxlan vrf TENANT-A vni 50001`) is the giveaway.
Asymmetric has no such construct.

*1 for the three route types, 1 for the sym/asym definition, 1 for identifying the lab as
symmetric **via the L3VNI**. "Symmetric" with no evidence scores 0 for that part.*

**B6 (3).** **Route targets are extended communities.** Without `send-community extended`,
the sending leaf strips them, so the receiving leaf gets an EVPN NLRI **with no RT attached
and therefore no VRF or MAC-VRF to import it into**.

The answer to the specific question: **routes are present but unusable**, not absent. In
the default-VRF EVPN table (`show bgp evpn`) they can be visible; what is empty is the
place that matters — `show vxlan address-table` has no remote MACs, the tenant VRF has no
remote prefixes, and hosts do not forward. That is precisely why this bug is nasty: BGP
summary looks perfect, EVPN routes exist, and nothing works.

*2 for "RTs are extended communities so import fails", 1 for the present-but-unimported
distinction. A candidate who says no routes arrive at all loses the third point.*

**B7 (3).** BGP's default multipath rule requires candidate paths to have an **identical
AS_PATH**, not merely an equal-length one. In a CLOS with per-spine ASNs, the two paths
from a leaf to a remote leaf are `65100 65003` and `65200 65003` — **same length, different
content**. Without `multipath-relax`, the router therefore refuses to treat them as
multipath and **installs exactly one path**, sending all traffic through a single spine and
silently halving (or worse) the fabric's bisection bandwidth while every `show` command
looks healthy. `bgp bestpath as-path multipath-relax` relaxes the comparison to length
only, and `maximum-paths` then permits the second one to be installed.

*2 for the identical-vs-equal-length distinction, 1 for the "one path installed, looks
healthy" consequence. Both `multipath-relax` and `maximum-paths` are needed — mention of
only one is fine here since the question asks about relax specifically.*

**B8 (3).**

| Phase | Spoke-to-spoke data path | Hub may summarise? | NHRP mechanism |
|---|---|---|---|
| 1 | **Always via the hub.** Spokes have no direct tunnels; the hub is the next-hop for everything. | **Yes** — spokes only ever need "send it to the hub", so a summary or even a default is fine. | NHRP **registration** only (spokes register their NBMA address with the NHS). |
| 2 | **Direct**, after the initiating spoke resolves the remote spoke. | **No** — the spoke's routing table must carry the remote spoke's specific prefix *with the remote spoke as next-hop*, so summarising breaks resolution. | NHRP **resolution request/reply**, triggered by the spoke's own routing lookup. The hub must **not** set next-hop-self. |
| 3 | **Via the hub for the first packets, then direct.** | **Yes** — this is the point of Phase 3; a summary or default via the hub is fine. | NHRP **redirect** (hub) + **shortcut** (spoke): the hub redirects, the spoke resolves and installs a shortcut that overrides the routing table. |

*1 per phase, each needing all three columns roughly right. The "Phase 2 cannot summarise,
Phase 3 can" contrast is the single most valuable line — award the Phase 3 point only if
that is present.*

**B9 (3).**
(a) **24 bytes** = outer IP header **20** + GRE header **4**.
(b) `1400 − 24 = ` **1376 bytes** of inner IP packet.
(c) `ping` works because it sends small packets by default (84 bytes total) that fit
easily. TCP does not: the endpoints negotiate MSS from **their own LAN interface MTU of
1500**, so MSS 1460 and full-size 1500-byte segments with **DF set**. Those need 1524 bytes
on a 1400-byte underlay and are dropped. The connection completes its handshake (small
packets) and then hangs the instant bulk data starts — the classic "ping works, transfer
hangs" signature.

Two fixes: set the **tunnel MTU to 1376** (`ip mtu 1376`) — the root correction, the
**belt** — and **clamp TCP MSS to 1336** (`1376 − 40`) — the **braces**, which works even
when ICMP is filtered and PMTUD is therefore dead. Accept the belt/braces labels either way
round if the candidate explains that the MTU fix is the correct one and the MSS clamp is
the ICMP-independent safety net.

*1 per part.*

**B10 (3).**
(a) BFD is a **purpose-built, stateless, fixed-format hello** with no routing state to
process — it runs in or close to the forwarding plane and can be offloaded to hardware,
so it can transmit every few tens of milliseconds. Routing-protocol hellos are handled by
the routing process on the general control plane, where per-packet cost and scheduling
jitter make sub-second timers unsafe. It also **decouples** detection from the protocol, so
one BFD session can serve OSPF, BGP and static routes simultaneously.
(b) **Echo mode** sends a packet that the neighbor's **forwarding plane loops straight
back** without the neighbor's control plane touching it — so it tests the actual **data
path in both directions**, including the neighbor's forwarding hardware. Asynchronous mode
only proves the two control planes can talk.
(c) In these labs every "router" is a **container sharing one host kernel and CPU**.
Scheduling jitter, host load, and Docker/veth latency produce delays far larger than a
50 ms BFD interval, so aggressive timers generate **false positives** — sessions flap,
adjacencies tear down, and you spend the lab debugging a problem the lab did not contain.

*1 per part.*

---

## Section 2 — Evidence reading (20)

### B-E1 (7)

(a) *(2)* The prefix **arrived and is best in the VPNv4 table** — `show bgp ipv4 vpn` shows
it under RD 65000:100, next-hop 10.0.0.2 (pe1), flagged `*>i` (valid, best, learned via
iBGP). It has **not been imported into the VRF**: `show bgp vrf CUST-A ipv4 unicast` is
empty, and consequently `show ip route vrf CUST-A` has only the connected route. The break
is precisely at the **VPNv4 → VRF import step**, and nowhere else.

*Award full marks only for naming the import step. "The VRF has no route" alone is
restating the output — 1.*

(b) *(3)* **Route-target import mismatch on pe2.** Inspect, under
`router bgp 65000 vrf CUST-A` → `address-family ipv4 unicast`, the **`rt vpn both
65000:100`** line (or a separate `rt vpn import`) and the presence of **`import vpn`**.
Either the RT value does not match what pe1 exported, or the `import vpn` statement is
missing entirely so the VRF never looks at the VPNv4 table at all.

*2 for "RT import", 1 for naming the specific config lines. Accept a candidate who checks
`show bgp ipv4 vpn` for the actual attached RT and compares — that is the better
diagnostic.*

(c) *(2)* Two faults that empty the VPNv4 table instead:
1. **The VPNv4 session to the RR is down, or `address-family ipv4 vpn` is not activated**
   for neighbor 10.0.0.1 on pe2.
2. **pe1 is not exporting** — missing `export vpn`, `rd vpn export`, or
   `label vpn export auto` — or the RR is not reflecting.

The output rules both out: the prefix is **present**, marked `i` (learned via iBGP) and
best, with pe1's loopback as next-hop. That proves the session is up, the VPNv4 AF is
activated on both ends, pe1 exported, and the RR reflected. Everything upstream of pe2's
import is proven working by this one line.

### B-E2 (7)

(a) *(3)* Working:
- `-s 1348` succeeds; Linux `ping -s` counts **ICMP payload**, so the inner IP packet is
  `1348 + 8 (ICMP header) + 20 (IP header) = ` **1376 bytes** — which is what the output's
  `1348(1376)` is telling you directly.
- `-s 1349` fails, so **1376 is the largest inner IP packet the path accepts**.
- Cross-check: `1376 + 24 (GRE + outer IP) = 1400`, exactly the underlay MTU. The
  arithmetic closes.
- Therefore the tunnel interface should carry **`ip mtu 1376`**.

*2 for reaching 1376 with visible working, 1 for the `ip mtu 1376` conclusion. An answer of
1376 with no working scores 1 — the question says show it.*

(b) *(2)* The hosts negotiated **MSS 1460**, derived from their own **1500-byte LAN
interface MTU** minus 20 (IP) and 20 (TCP). Nothing in the path rewrote it. So once the
handshake (small packets) completes and bulk transfer starts, the endpoints emit
**1500-byte segments with DF set**, which need 1524 bytes on the underlay and are dropped.
`curl` hangs having received 0 bytes: the connection is established but no data segment
ever survives.

(c) *(2)* PMTUD requires the dropping router to return **ICMP type 3 code 4
(fragmentation needed, DF set)** carrying the next-hop MTU, and requires that message to
reach the sender. Here it does not — either it is filtered along the path or by the host's
own policy, or the router does not generate it — producing a classic **PMTUD black hole**:
packets vanish with no feedback, which is why the failure is a silent hang rather than an
error.

The fix that does not depend on PMTUD at all: **TCP MSS clamping** to **1336**
(`1376 − 40`), applied on the tunnel/edge router. It rewrites the MSS in the SYN so the
endpoints never generate an oversized segment in the first place; no ICMP required.

*1 for the ICMP black hole, 1 for MSS clamping with a value that matches their own 1376.*

### B-E3 (6)

Any well-reasoned ranking scores; this is the model. **2 points each**: 1 for the cause,
1 for a command that genuinely discriminates.

1. **leaf1 is not originating the Type-2 at all** — VLAN 10 has no EVPN instance
   (`vlan 10 / rd auto / route-target both 65000:10010 / redistribute learned`), or
   Ethernet3 is not an access port in VLAN 10, or `vxlan vlan 10 vni 10010` is missing from
   Vxlan1.
   **Command:** `show bgp evpn route-type mac-ip` **on leaf1**. If leaf1 does not have its
   *own* host's route, this is an origination problem and nothing downstream matters. This
   is the right first test precisely because leaf3 *does* show its own — the symmetric
   check costs nothing and splits the problem in half.
2. **EVPN address-family not activated** on a neighbor — on leaf1 toward the spines, or on
   a spine toward leaf3. No EVPN NLRI is exchanged in that direction, so nothing from leaf1
   ever arrives.
   **Command:** `show bgp evpn summary` on leaf1, leaf3, and the spine — check the neighbor
   appears **in the EVPN AF** and look at the prefixes-received counter.
3. **`send-community extended` missing** on a neighbor, so RTs are stripped and the route
   cannot be imported into VLAN 10's MAC-VRF.
   **Command:** `show bgp evpn route-type mac-ip` **on the spine** (proves the spine holds
   leaf1's route, so origination and propagation are fine) combined with
   `show vxlan address-table` on leaf3 showing no remote MAC — present upstream, unimported
   downstream is this bug's exact signature.

*Underlay reachability is already proven by the successful loopback ping, so a candidate
who lists "underlay broken" as a candidate loses that item's marks — the question hands
them that elimination.*

---

## Section 3 — Implementation on paper (25)

### C1 (10) — pe1, FRR

```text
interface lo
 ip address 10.0.0.2/32
 ip router isis CORE
 isis passive
!
interface eth1 vrf CUST-A
 description to CE1
 ip address 192.168.10.2/30
!
interface eth2
 description to P1
 ip address 10.1.0.1/30
 ip router isis CORE
 isis network point-to-point
 isis metric 10
 mpls enable
!
router isis CORE
 net 49.0001.0000.0000.0002.00
 is-type level-2-only
 metric-style wide
 segment-routing on
 segment-routing prefix 10.0.0.2/32 index 2
!
router bgp 65000
 bgp router-id 10.0.0.2
 neighbor 10.0.0.1 remote-as 65000
 neighbor 10.0.0.1 update-source lo
 !
 address-family ipv4 unicast
  no neighbor 10.0.0.1 activate
 exit-address-family
 !
 address-family ipv4 vpn
  neighbor 10.0.0.1 activate
  neighbor 10.0.0.1 send-community both
 exit-address-family
!
router bgp 65000 vrf CUST-A
 bgp router-id 10.0.0.2
 no bgp ebgp-requires-policy
 neighbor 192.168.10.1 remote-as 65001
 !
 address-family ipv4 unicast
  neighbor 192.168.10.1 activate
  label vpn export auto
  rd vpn export 65000:100
  rt vpn both 65000:100
  export vpn
  import vpn
 exit-address-family
```

Scoring (10):
- 1 — `ip router isis CORE` on lo and eth2 (**not** `isis enable` — that syntax is wrong on
  this FRR version and the repo calls it out)
- 1 — `mpls enable` on the **core-facing** interface. Putting it on the customer-facing
  interface as well is harmless; omitting it from eth2 costs the point.
- 2 — IS-IS instance with the correct NET, `is-type level-2-only`, `metric-style wide`,
  `segment-routing on`, and `segment-routing prefix … index 2`
- 2 — the **two separate BGP instances**: a global one for VPNv4 and a
  `router bgp 65000 vrf CUST-A` one for the CE session. A candidate who puts the eBGP CE
  neighbor in the global instance scores 0 here — this is the structural idea of the lab.
- 2 — `address-family ipv4 vpn` (**not** `address-family vpnv4`, which is the syntax the
  repo explicitly warns is wrong for this FRR version) with the neighbor activated and
  `send-community both`
- 1 — `rd vpn export` / `rt vpn both` / `export vpn` / `import vpn`
- 1 — `label vpn export auto` and `no bgp ebgp-requires-policy`

**The topology-file setting (not scored above; award back up to 2 bonus points against
losses elsewhere):**

```yaml
sysctls:
  net.mpls.platform_labels: "1048575"
```

It must be set via **`sysctls:`, not `exec:`**, because sysctls are applied **before the
container process starts**, so the kernel's MPLS label space exists before FRR comes up and
starts installing label entries. With `exec:` it would be applied too late. Without it the
label space is 0: IS-IS forms adjacencies, SR advertises prefix-SIDs, BGP exchanges VPNv4
routes — **every control-plane check passes** — and no labelled packet is ever forwarded,
because the kernel refuses to install the MPLS routes.

### C2 (8) — leaf1, TENANT-A, Arista EOS

```text
vrf instance TENANT-A
ip routing vrf TENANT-A
!
ip virtual-router mac-address 00:1c:73:aa:aa:aa
!
vlan 10
!
interface Ethernet3
   switchport access vlan 10
!
interface Vlan10
   vrf TENANT-A
   ip address virtual 10.10.10.1/24
   no autostate
!
interface Vxlan1
   vxlan source-interface Loopback0
   vxlan udp-port 4789
   vxlan vlan 10 vni 10010
   vxlan vrf TENANT-A vni 50001
!
router bgp 65001
   router-id 10.0.0.1
   maximum-paths 2 ecmp 2
   bgp bestpath as-path multipath-relax
   neighbor 10.1.0.1 remote-as 65100
   neighbor 10.1.0.1 send-community extended
   neighbor 10.2.0.1 remote-as 65200
   neighbor 10.2.0.1 send-community extended
   !
   address-family ipv4
      neighbor 10.1.0.1 activate
      neighbor 10.2.0.1 activate
      network 10.0.0.1/32
   !
   address-family evpn
      neighbor 10.1.0.1 activate
      neighbor 10.2.0.1 activate
   !
   vlan 10
      rd auto
      route-target both 65000:10010
      redistribute learned
   !
   vrf TENANT-A
      rd 10.0.0.1:50001
      route-target import evpn 65000:50001
      route-target export evpn 65000:50001
      redistribute connected
```

Scoring (8):
- **2 — `neighbor <spine> send-community extended` on both spine neighbors.** This is one
  of the two double-mark lines. Without it the fabric converges and does not forward.
- **2 — `ip virtual-router mac-address`.** The second double-mark line: `ip address
  virtual` on the SVI does not function without the global virtual-router MAC, so every
  leaf's anycast gateway is inert and hosts cannot reach their own default gateway.
- 1 — Vxlan1 with both `vxlan vlan 10 vni 10010` (L2VNI) and `vxlan vrf TENANT-A vni 50001`
  (L3VNI). Missing the L3VNI is not symmetric IRB.
- 1 — `address-family evpn` with both neighbors activated
- 1 — the `vlan 10` EVPN instance with `route-target both` and `redistribute learned`
- 1 — the `vrf TENANT-A` EVPN instance with import/export RTs and `redistribute connected`

`no autostate`, `maximum-paths`/`multipath-relax`, and `ip routing vrf` are expected but
not individually scored; note them in feedback if missing.

### C3 (7) — DMVPN Phase 3

**Hub (4):**
- Tunnel mode **mGRE — multipoint GRE** (1 point). A point-to-point GRE tunnel per spoke is
  not DMVPN.
- NHRP role: the hub is the **Next Hop Server (NHS)**; spokes register their
  tunnel-IP → NBMA-IP mapping with it (1 point).
- The Phase-3 distinguishing command is **NHRP redirect** (`ip nhrp redirect`) — the hub
  tells an ingress spoke "you are going the long way round, go resolve the destination
  directly" (1 point). *Phase 2 has no redirect; resolution is driven by the spoke's own
  routing lookup.*
- Routing: `dmvpn-phase3` uses **OSPF network type point-to-multipoint**, and the hub
  **may summarise** — including advertising just a default (1 point, requires both halves).

**Spoke (3):**
- Finds the hub by **static NHRP mapping of the hub's tunnel IP to its NBMA (public)
  address** plus an NHS statement, then registers (1 point).
- The Phase-3 command is **NHRP shortcut** (`ip nhrp shortcut`), which permits installing a
  next-hop override learned from a redirect (1 point).
- Routing table **before**: the remote spoke's subnet is reached **via the hub** (often
  only as part of a summary or default). **After** the first packets trigger a redirect and
  resolution: an **NHRP shortcut entry / next-hop override** points at the remote spoke's
  NBMA address directly, and subsequent packets go spoke-to-spoke without the routing table
  itself changing (1 point).

*The distinction worth the most in feedback: Phase 2 needs specific routes because
resolution is driven by the RIB; Phase 3 works with a summary because the shortcut
overrides the RIB. A candidate who describes Phase 3 as "Phase 2 but better" without that
mechanism scores 3 of 7.*

---

## Section 4 — Design & trade-offs (15)

### D1 (8)

*(1.5 per approach for the three columns, 2 for the deciding factor, 1.5 for the VRF-Lite
scenario.)*

| | Data-plane tenant identity | Transit devices need | Adding tenant #11 |
|---|---|---|---|
| **VRF-Lite** | None in the packet — separation is by **802.1Q tag / subinterface per tenant per link** | Every hop needs the VRF, a subinterface per tenant per link, and a routing adjacency per tenant | Touch **every device on the path** — O(tenants × hops); this is where it falls over |
| **MPLS L3VPN** | The **VPN label** (inner MPLS label) | **Nothing tenant-aware.** P routers run IGP + label switching and have never heard of the customer | Touch **only the PEs** that host the tenant |
| **EVPN Type-5** | The **VNI** in the VXLAN header, with RTs governing import | **Nothing tenant-aware.** Spines route IP and propagate BGP EVPN | Touch **only the leaves** that host the tenant |

**Deciding factor between L3VPN and EVPN:** the transport and the hardware you already own.
EVPN/VXLAN needs only a **routed IP underlay** and is what modern DC silicon and DC
operational tooling are built around; MPLS L3VPN needs an **MPLS-capable core** with label
distribution and is the established answer on WAN/SP gear. A secondary factor that often
decides it: if you need **Layer 2 extension** as well as L3 isolation, EVPN gives you
Type-2/Type-3 in the same control plane, whereas L3VPN is L3-only and you would be bolting
on a separate L2VPN.

**Where VRF-Lite is genuinely right:** small, short paths where a label or overlay plane is
not worth its operational weight — two or three tenants across a single pair of
routers/firewalls, a management VRF separated from production at a branch, or any platform
that simply cannot do MPLS or VXLAN. Accept any answer with a *low tenant count and a low
hop count* as its justification.

### D2 (7)

(a) *(3 — 1 each)*
- **MLAG** — failure of a **member link or of the peer switch**. A member-link loss is
  handled at LACP speed (sub-second; the port-channel just loses a member and hashes
  elsewhere); peer failure is detected by the **peer-link keepalive**, in the order of
  seconds.
- **VRRP** — total failure of the **master**, via **missed advertisements**. With the
  default 1 s advertisement interval, that is roughly **3 seconds plus skew**.
- **BFD** — failure of the **forwarding path** between two neighbors, **sub-second**
  (e.g. 3 × 300 ms ≈ 900 ms), independently of the routing protocol riding on it.

(b) *(2)* VRRP's blind spot is that it only monitors **itself and its peer on the LAN
segment**. The master can be perfectly healthy on the host-facing side while having **lost
its uplink**. It keeps sending advertisements, keeps winning the election, and keeps
attracting every host's default-gateway traffic — into a **black hole**. Tracking an
uplink interface or a route decrements the master's priority when the uplink fails, letting
the backup take over. This is the reason tracking exists, not a refinement of it.

(c) *(2)* Any one of these, stated as an interaction:
- **Aggressive BFD + a busy or virtualised control plane** → false-positive session loss →
  BFD tears down the OSPF adjacency → routes withdraw → **VRRP tracking follows the routes
  and fails the gateway over too.** A transient CPU spike becomes a full gateway failover,
  and the flap repeats. Neither mechanism alone would have done that.
- **MLAG + VRRP during a peer-link failure** → both peers believe they should be forwarding
  for the virtual IP → **split brain**, duplicated or black-holed traffic. It is why the
  MLAG keepalive runs on a path separate from the peer link.
- **VRRP tracking a route that BFD withdraws in under a second** → gateway priority flaps
  in lockstep with a flapping link, producing repeated failovers rather than one clean one;
  the fast detector amplifies instability instead of damping it.

---

## Section 5 — Troubleshooting narrative (10)

### B-E4 — model answer

**1. What the healthy IGP tells you and what it does not (3).** The IGP proves the
**control plane and the IP forwarding plane** are healthy: adjacencies are up, loopbacks are
in the LSDB, and IP packets between core loopbacks are delivered. It proves **nothing about
the MPLS forwarding plane**. A loopback-to-loopback ping is an IP packet the core can route
natively; customer VPN traffic **cannot** be — the egress PE identifies the customer only
by the VPN label, and the transport label is what gets it there. So the label imposition,
swap, and pop entries can be entirely missing at some hop while every IP test in the core
passes. In addition, no P router has any route to the customer prefix, and is not supposed
to — so IP-level tests can never exercise the path the customer traffic takes.

*3 for the control-plane/forwarding-plane split with the reason customer traffic must be
labelled. 1 if the candidate only says "ping doesn't test MPLS" with no mechanism.*

**2. Three label-plane commands (3).** *(1 each; must state the healthy expectation.)*
- `show mpls table` on each core router — healthy: an entry for each node-SID (16001–16005)
  with a swap-or-pop action and an outgoing interface toward the right neighbor.
- `show isis segment-routing prefix-sids` (or `show isis database detail`) — healthy: every
  node advertising its prefix-SID index, all deriving from the same SRGB base, so the
  labels agree domain-wide.
- `show bgp ipv4 vpn <prefix>` on pe1 — healthy: the remote **VPN label** is present and
  the next-hop resolves **through an LSP** with a label stack, not merely through an IP
  route. On the Linux/FRR nodes, `ip -M route` showing installed kernel MPLS entries is an
  equally good answer.

**3. Most likely fault class and where it lives (2).** **Broken label switching at one hop
in the transit path** — the classic instances being a **missing `mpls enable` on a single
core interface**, an **MPLS label space not sized** (`net.mpls.platform_labels` unset or
applied via `exec:` instead of `sysctls:` so it landed after FRR started), or an **SRGB
mismatch** so two routers disagree about which label means which node. It lives in the
**transit P routers**, because both PEs' control planes have already been proven — the
route is present, imported, and resolved on pe1, and pe2 advertised it.

**4. Localising without shutting anything down (1).** Walk the path hop by hop with
`show mpls table` on each core router, checking that each one has an entry for pe2's
node-SID with a plausible outgoing interface — the first router with no entry, or with an
entry pointing the wrong way, is the fault. Equivalently, run an **MPLS-aware traceroute**
from pe1 and find the last hop that responds. Cross-check `mpls enable` on every core
interface against the topology file; a single omitted interface is the textbook version of
this bug.

**5. Verification (1).** Prove the **label** path, not just reachability: a traceroute that
displays the **MPLS label stack** at each hop and shows the expected node-SID being swapped
along the way, plus `show mpls table` on the repaired router showing the entry now
installed. Then the customer test from ce1 with the correct source. "The ping works now" is
not sufficient — the ping could succeed via a different path than the one you believe you
repaired.

---

## Remediation table

| Question | Topic | Lab |
|---|---|---|
| B1, B2, B4, C1 | Segment Routing, SRGB, label stack, PHP | `labs/mpls-sr-blank`, `labs/mpls-sr-isis-bgp`, `labs/mpls-ldp` |
| B3, B-E1 | RD vs RT, VPNv4 import | `labs/mpls-sr-blank`, `labs/debug-mpls-sr-isis-bgp` |
| B5, B6, B-E3, C2 | EVPN route types, IRB, extended communities | `labs/vxlan-evpn`, `labs/debug-vxlan-evpn`, `labs/evpn-border-ceos` |
| B7 | CLOS underlay, ECMP, multipath-relax | `labs/spine-leaf`, `labs/debug-spine-leaf` |
| B8, C3 | DMVPN phases, NHRP | `labs/dmvpn-phase1`, `labs/dmvpn-phase2`, `labs/dmvpn-phase3`, `labs/debug-dmvpn-phase1` |
| B9, B-E2 | GRE overhead, MTU, PMTUD, MSS | `labs/mtu-pmtud-troubleshooting`, `labs/gre-basics`, `labs/debug-gre-basics` |
| B10, D2 | BFD, VRRP tracking, MLAG, HA interaction | `labs/bfd-ospf`, `labs/bfd-bgp`, `labs/vrrp`, `labs/ha-network-design-ceos` |
| D1 | Tenant isolation approaches | `labs/vrf-lite`, `labs/mpls-sr-blank`, `labs/evpn-border-ceos`, `labs/debug-vrf-lite` |
| B-E4 | Label-plane troubleshooting | `labs/mpls-ldp` (mid-path LSP blackhole), `labs/debug-mpls-sr-isis-bgp` |
