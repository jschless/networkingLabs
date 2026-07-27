# Exam C — Answer Key & Grading Notes

The theme running through this exam is **state and path** — where state lives, what packet
it was built from, and whether the path agrees with it. Sections 2 and 5 both turn on it.
Grade generously on wording and hard on whether the candidate reasons about the *order*
things happen in.

---

## Section 1 — Concepts & mechanisms (30)

**C1 (3).**
- **DHCP snooping** — stops a **rogue DHCP server** handing out addresses/gateways. It
  consumes DHCP traffic on untrusted ports and **produces the binding table**
  (MAC ↔ IP ↔ VLAN ↔ port), which is the artefact the other two need.
- **Dynamic ARP Inspection** — stops **ARP spoofing / ARP cache poisoning** (a
  man-in-the-middle). It **consumes** the binding table, validating that an ARP reply's
  sender IP/MAC pair matches a real binding on that port.
- **IP Source Guard** — stops **IP source-address spoofing** by a host that has an address
  but lies about it. It also **consumes** the binding table, filtering traffic whose source
  IP does not match the binding for that port.

DAI and IP Source Guard depend on snooping because the binding table is their only source
of truth about which IP legitimately lives on which port — without it they have nothing to
compare against. A **statically addressed server** on a snooping VLAN has no DHCP
transaction and therefore **no binding**, so DAI and IP Source Guard will drop its ARP and
its traffic. It needs a **static binding entry** configured manually (or the port marked
trusted).

*2 for the three mechanisms with attack + role, 1 for the static-host consequence. The
static-host trap catches candidates who memorised the feature list — award it only for
naming the static binding as the remedy.*

**C2 (3).** **Strict uRPF:** accept the packet only if the route back to its source IP
points out **the same interface it arrived on**. **Loose uRPF:** accept if the source is
reachable via **any** interface — effectively "is this source in the routing table at all",
which catches bogons and unrouteable space only.

Strict mode drops legitimate traffic whenever the network is **asymmetrically routed** —
the packet arrives on interface A but the best return path is out interface B. That is
**normal, not exceptional**, at a multihomed edge with different inbound and outbound
preferences (exactly the design in Exam A D1), and on any ECMP path where forward and
reverse hash differently.

Placement: **strict** on a **customer/access-facing edge port** where you know the single
subnet that should be behind it; **loose** (or nothing) on **transit links** between
providers or in a multihomed core, where asymmetry is designed in.

*1 per definition, 1 for the asymmetry condition, 1 for correct placement — cap at 3.*

**C3 (3).**
(a) `ToS = DSCP << 2` → `46 << 2 = 184 = 0xb8`. The two low-order bits you shifted past are
the **ECN** bits, not part of DSCP.
(b) `0x2e` is 46 written **directly** into the ToS byte instead of shifted — it describes a
different DSCP entirely (11 = AF12-ish, with ECN bits set), so nothing marked EF matches it.
(c) **Mark at the trust boundary, as close to the source as possible; queue at the
congestion point.** They differ because marking is a *classification* decision that needs
application context and only needs doing once, whereas queueing only does anything where
there is actual contention — the WAN egress. Scheduling on an uncongested link costs CPU
and changes nothing; marking at the congested link is too late, because by then you no
longer have the information to classify reliably.

*1 per part.*

**C4 (3).**
(a) `rate` is the **guaranteed minimum** a class gets when everyone wants their share.
`ceil` is the **maximum it may borrow up to** from the parent — and it can only borrow when
other classes are **not using their guaranteed rate**. On a saturated link every class
collapses back toward its `rate`; `ceil` is what lets a single active class use the whole
2 Mbit/s when the link is otherwise idle.
(b) **SFQ on data** because best-effort bulk data is *many concurrent flows of equal
entitlement*; SFQ hashes flows into separate queues and round-robins them, so one greedy
TCP download cannot starve everything else in the class. **GRED/WRED on video** because
video is **responsive (TCP-based)** traffic: dropping a few packets *early and randomly*
before the queue fills signals the sender to slow down, avoiding tail-drop bursts and
global synchronisation. Reversed, neither works: WRED's early-drop signal is wasted on
traffic that will not respond to it, and SFQ provides no congestion signal at all. (Voice
gets neither — it is strict priority with a shallow queue, where you would rather drop than
delay.)

*1 for rate/ceil with the borrowing condition, 2 for the SFQ/GRED reasoning — 1 if they get
the assignment right without the responsive/unresponsive argument.*

**C5 (3).** An **L7** load balancer can see and act on the application payload: route by
`Host` header or URL path, terminate TLS, insert headers, do content-aware health checks,
and **retry a failed request on another backend** — an L4 balancer sees only the 5-tuple and
cannot do any of it. **The cost:** it must terminate the TCP connection (and usually TLS),
so it is a stateful, CPU-and-memory-hungry chokepoint, it adds latency, it breaks
end-to-end TLS, and the backends lose sight of the real client IP.

**X-Forwarded-For** exists to solve that last consequence: the proxy's own address becomes
the source IP the backend sees, so the original client IP is carried in a header instead.
It is untrustworthy unless **the backend only honours XFF from a known, trusted proxy that
overwrites rather than appends** — otherwise any client can simply set the header itself
and forge its own source address for anything downstream that logs or authorises on it.

*1 for the L7 capability, 1 for the cost, 1 for XFF including the trust condition. The
trust condition is the graded half of the XFF answer.*

**C6 (3).** Roles: **supplicant** (the client), **authenticator** (the switch or AP), and
**authentication server** (RADIUS). Supplicant ↔ authenticator speaks **EAPOL** (EAP over
LAN); authenticator ↔ server speaks **RADIUS**, with the EAP messages carried inside RADIUS
attributes. The authenticator is a **relay** — the EAP conversation is logically end-to-end
between supplicant and server, and the switch cannot read it.

(a) **MAB (MAC Authentication Bypass)** — for devices with no supplicant (printers,
cameras, badge readers): the switch learns the MAC and presents it to RADIUS as the
credential. The trade-off: **MAC addresses are trivially spoofable and are transmitted in
clear on every frame**, so MAB is authentication in name only; anyone who can read one
frame can impersonate the device. Mitigate with device profiling and a deliberately
restrictive authorisation profile.

(b) **EAP-TLS is mutual certificate authentication** — the client proves possession of a
private key bound to a certificate the server trusts, and the server does the same to the
client. **PEAP/MSCHAPv2** only presents a **server** certificate; the client authenticates
with a password-derived hash inside the tunnel. So PEAP falls to a guessed or stolen
password, and — critically — if the supplicant does not validate the server certificate, an
attacker stands up a rogue RADIUS, harvests MSCHAPv2 challenge/response pairs, and cracks
them offline. EAP-TLS has no password to steal.

(c) **Dynamic VLAN assignment**: the RADIUS **Access-Accept** carries tunnel attributes
(`Tunnel-Type = VLAN`, `Tunnel-Medium-Type = 802`, `Tunnel-Private-Group-ID = <vlan>`) and
the switch programs the port into that VLAN. The **authentication server decides**; the
switch enforces. That is what makes identity-driven segmentation possible without
per-port configuration.

*1 per part.*

**C7 (3).**

| Mechanism | The question only it answers |
|---|---|
| **syslog** | "**What happened, and exactly when?**" — the only one that records a discrete event (link flap, config change, process crash) at the instant it occurred. |
| **SNMP** | "**What is the value now, and what is the trend?**" — the only one giving regular numeric time series for capacity planning and thresholds. |
| **NetFlow** | "**Who talked to whom, and how much?**" — the only one with conversation-level accounting across *all* traffic, without storing payload. |
| **SPAN** | "**What was actually in the bytes?**" — the only one with payload. |

Load, least to most: **syslog** (event-driven, tiny — though it inverts during a storm) <
**SNMP** (periodic polling; scales with OIDs × devices × interval) < **NetFlow**
(per-flow state on the device plus export bandwidth proportional to flow count) < **SPAN**
(duplicates the entire traffic volume; oversubscribes the monitor port and the collector).

*2 for the four distinctions, 1 for a defensible ranking with SPAN at the top.*

**C8 (3).**
(a) **Idempotence**: applying the operation any number of times leaves the same end state as
applying it once. It matters for configuration because config automation is **run
repeatedly** — on a schedule, as a retry after partial failure, or to correct drift. A
non-idempotent change appends duplicates, bounces a session, or errors on the second run,
which means you cannot safely re-run it — and the entire desired-state model depends on
being able to re-run it.
(b) Verifying locally proves only that the **local box accepted the config**. It misses the
whole class of changes that are syntactically valid, commit cleanly, and **have no effect on
the relationship**: a mismatched remote-AS, a peer that never came up, a policy the neighbor
rejects, a filter that drops the advertisement, or a change that needs a soft-reset to take
effect. The peer's view is the only ground truth for whether the change *did* anything.
(c) Any one: **NETCONF has datastores and transactions** — a candidate datastore, `lock`,
and `commit` / confirmed-commit with automatic rollback — so a multi-command change is
atomic and revertible. **eAPI is a stateless sequence of CLI commands over HTTP** with no
candidate store, no lock, and no transaction, so **partial application is a real outcome you
must write code around**: capture prior state, verify after, and implement your own
rollback. (Also acceptable: NETCONF is schema-driven via YANG so payloads can be validated
before sending, whereas eAPI JSON is command output, not a model.)

*1 per part. For (c), an answer that only says "XML vs JSON" scores 0 — the question
explicitly excludes encoding.*

**C9 (3).**
(a) On Linux/netfilter the **nat prerouting (dstnat) hook runs before the routing decision
and before the filter forward hook**. By the time a packet reaches `forward`, its
destination has **already been rewritten**, so the filter rule must match the
**post-DNAT (real) destination and port**, never the published VIP.
(b) **Conntrack** records the flow on its first packet — including the NAT binding — and
classifies subsequent packets as `established`/`related`. That lets a single
`ct state established,related accept` rule permit all return traffic, and it un-NATs
replies automatically without a mirror-image rule per service.
(c) **Hairpin NAT** is an internal client reaching an internal server via that server's
**public** VIP. The packet goes to the firewall, is DNATted back into the subnet it came
from, and the server replies **directly** to the client — bypassing the firewall, so the
reply's source address is the server's real IP rather than the VIP, and the client discards
it as unrelated. **Symptom: the service works perfectly from outside and not at all from
inside using the public name.** Fix: also **SNAT** the hairpin flow to the firewall's
address, forcing the return through the firewall.

*1 per part.*

**C10 (3).** **Identical:** the FHRP concept itself — a group of routers share a **virtual
IP and virtual MAC**, one is active, and hosts point their default gateway at the VIP,
oblivious to which physical box is serving it.

**Two genuine differences**, any two of:
- VRRP is an **IETF open standard** (RFC 5798); HSRP and GLBP are **Cisco-proprietary**.
- Transport and addressing: VRRP is **IP protocol 112 to 224.0.0.18**; HSRP is **UDP 1985**
  to 224.0.0.2 (v1) / 224.0.0.102 (v2).
- Virtual MAC ranges: VRRP `00:00:5e:00:01:XX`; HSRP `00:00:0c:07:ac:XX`.
- VRRP has the concept of the **address owner** — a router whose real interface address *is*
  the VIP, which runs at priority 255 and always wins. HSRP has no equivalent.
- **GLBP** is active/**active**, load-sharing across multiple forwarders via ARP replies;
  VRRP and HSRP are active/standby for a given group (VRRP load-shares only by running
  multiple groups).

**The surprise:** **VRRP preempts by default; HSRP does not.** Someone who learned HSRP
expects a recovered router to sit as backup until the current master fails, and instead
watches it seize mastership the moment it boots — causing a *second* brief outage right
after the first one is resolved, often mid-maintenance-window.

*1 for the shared concept, 1 for two differences, 1 for preemption. Accept "VRRP's default
priority is 100 and ties break on highest IP" as a differences item.*

---

## Section 2 — Evidence reading (20)

### C-E1 (7)

(a) *(3)* The `nat prerouting` hook (priority `dstnat`, −100) runs **before the routing
decision and before the `filter forward` hook** (priority `filter`, 0). By the time the
packet reaches `forward`, DNAT has **already rewritten** the destination to
`172.16.0.11:8443`. The forward rule matches `ip daddr 203.0.113.10 tcp dport 443` — a
combination that no longer exists on any packet at that point — so it never matches, and
the chain's `policy drop` silently discards all 812 packets. The counters state this
outright: 812 translations, 0 accepts.

*3 for the hook-ordering argument. A candidate who says "the rule is wrong" without the
ordering gets 1.*

(b) *(2)*

```text
iifname "eth0" oifname "eth1" ip daddr 172.16.0.11 tcp dport 8443 counter accept
```

*Accept `ct state new` added, or matching on `oifname` only. Zero if they match the VIP
anywhere.*

(c) *(2)* **Yes, the `established,related` counter will start incrementing** — it currently
reads 0 only because no flow has ever completed a first packet. Once the SYN is accepted by
the corrected rule, conntrack creates the entry and **every subsequent packet in both
directions** — the SYN-ACK, the ACK, and all data — matches `established`. It will quickly
become the highest counter in the chain.

**The masquerade rule plays no part in this flow.** It matches DMZ-sourced traffic leaving
via `eth0` — i.e. DMZ-**initiated** connections to the internet. Return packets of the
published service are un-NATted automatically by **conntrack reversing the existing DNAT
binding**, which is not a rule and does not increment a counter. That is why it reads 0 and
will stay 0 for this traffic.

*1 for each half. The "conntrack reverses the DNAT, no rule needed" point is the graded
idea.*

### C-E2 (7)

(a) *(2)* **Voice traffic is not being classified into class 1:10 at all.** The class has
`Sent 0 bytes 0 pkt` while the voice client is provably transmitting 500 kbit/s. The
scheduler is fine; the **classifier** is not matching.

(b) *(2)* It is falling into the **default class, 1:30** — the HTB default in this lab.
Evidence: 1:30 has sent ~22 MB against 1:20's ~14.9 MB despite both classes having an
identical `rate 600Kbit`, so 1:30 is carrying more than its own client's share; and 1:30
has by far the worst drops (1904) and the deepest backlog (41 packets). The voice stream is
therefore sitting at **prio 3 behind bulk data**, sharing an SFQ queue — the exact outcome
the design existed to prevent. Worse, UDP voice does not back off in response to those
drops.

*1 for naming 1:30, 1 for citing the byte/drop asymmetry as evidence.*

(c) *(3)* Two likely causes:
1. **The `tc` filter matches the wrong ToS value** — `0x2e` (the DSCP number written
   directly) instead of `0xb8` (DSCP << 2), or a match with no `0xfc` mask so the two ECN
   bits break the comparison whenever ECN is negotiated.
2. **The traffic is never marked EF in the first place** — the client is not setting DSCP,
   or the marking rule upstream of the shaper is missing or misordered.

**The command that separates them:** a capture on the voice ingress interface showing the
actual ToS byte on the wire —
`tcpdump -v -i eth1 -c 5` and read the `tos` field (or `tcpdump -i eth1 'ip[1] & 0xfc = 0xb8'`).
If the packets are marked `0xb8`, cause 1; if they arrive as `0x00`, cause 2.
`tc -s filter show dev eth4` showing zero matched packets is an acceptable alternative
answer, but it is weaker: it proves the filter did not match without proving whether the
marking was there to match.

*2 for the two causes, 1 for a command that genuinely discriminates. Award the full point
for the capture answer; 0.5 for the `tc -s filter` answer alone.*

### C-E3 (6)

(a) *(2)* **Asymmetric return path.** Forward: `client → edge` (where DNAT/conntrack state
is created) `→ web1`. Return: `web1 → edge2 → client` — the reply is routed out of the DMZ
via the second router, bypassing the device holding the NAT state.

**The proof is in the capture itself:** the SYN-ACK's source is `172.16.0.11.8080`, the
server's **real** address and port. Had it traversed `edge`, conntrack would have reversed
the DNAT and rewritten the source back to the VIP. Seeing the untranslated address on
`edge2` is direct evidence the packet never went through the translating device.

*1 for naming asymmetry and the two paths, 1 for using the untranslated source address as
the evidence. The second point is the discriminator between a candidate reading the output
and one reciting a pattern.*

(b) *(1)* 1 s → 2 s → 4 s is **exponential backoff on SYN-ACK retransmission**, which only
the **server** does. So the server sent its SYN-ACK and never received the client's ACK —
the confusion is on the return path, and the client never saw the SYN-ACK at all. Had the
*client* been the confused end we would be looking at repeated **SYNs**, not SYN-ACKs.

(c) *(2)* Because **the NAT/conntrack state lives on `edge` alone**. `edge2` has a valid
route and will happily forward the packet — but it holds **no binding for this flow**, so it
forwards it **untranslated**. The client receives a SYN-ACK from `172.16.0.11`, an address it
never contacted, and discards it (or RSTs) as unrelated to its connection. Routing was never
the problem; **state is not routable**, and the routing decision sent packets past the only
box that had it. (Any stateful firewall in that path would likewise drop the reply as
out-of-state.)

(d) *(1)* **Routing layer:** make the DMZ return path deterministic — point the web servers'
default route (or a specific route for `203.0.113.0/29`) at `edge`, the device holding the
state. **Design layer:** stop depending on routing for symmetry at all — put the load
balancer in the return path by source-NATting at the LB so backends reply to the LB by
definition, or run the stateful devices as an HA pair with **session state
synchronisation** (`service-ha`) so either box can handle the reply.

---

## Section 3 — Implementation on paper (25)

### C1 (10) — nftables screened subnet

```text
table ip nat {
    chain prerouting {
        type nat hook prerouting priority dstnat; policy accept;
        iifname "eth0" ip daddr 203.0.113.10 tcp dport 443 dnat to 172.16.0.11:8443
    }
    chain postrouting {
        type nat hook postrouting priority srcnat; policy accept;
        ip saddr 172.16.0.0/24 oifname "eth0" masquerade
        ip saddr 10.1.0.0/24   oifname "eth0" masquerade
    }
}

table ip filter {
    chain input {
        type filter hook input priority filter; policy drop;
        ct state established,related accept
        iif "lo" accept
        iifname "eth2" tcp dport 22 accept
    }
    chain forward {
        type filter hook forward priority filter; policy drop;
        ct state invalid drop
        ct state established,related accept
        # published DMZ service — matched POST-DNAT
        iifname "eth0" oifname "eth1" ip daddr 172.16.0.11 tcp dport 8443 accept
        # DMZ may reach the internet
        iifname "eth1" oifname "eth0" accept
        # LAN may reach the internet and the DMZ
        iifname "eth2" oifname { "eth0", "eth1" } accept
        # DMZ -> LAN: no rule. The policy drop is the control.
    }
    chain output {
        type filter hook output priority filter; policy accept;
    }
}
```

Scoring (10):
- **3 — the published-service forward rule matches the post-DNAT destination**
  (`172.16.0.11:8443`). Matching the VIP here is the single most common error and scores 0
  for this item, however correct the rest is.
- 2 — `policy drop` on `forward`, plus `ct state established,related accept`
- 2 — DNAT in `prerouting` and masquerade/SNAT in `postrouting`, with correct hooks and
  priorities
- 2 — **the DMZ→LAN restriction implemented as an absence of a rule** plus the default drop.
  Award the full 2 only if the candidate also recognises that **LAN→DMZ replies still work
  via conntrack**, so no DMZ→LAN rule is needed for them. A candidate who adds an explicit
  DMZ→LAN drop rule for clarity keeps the marks; one who adds a DMZ→LAN *accept* to "make
  replies work" scores 0 here — they have opened the exact hole the screened subnet exists
  to close.
- 1 — `ct state invalid drop` and a sane `input` chain

### C2 (8) — cEOS access hardening

```text
ip dhcp snooping
ip dhcp snooping vlan 10
!
ip arp inspection vlan 10
!
interface Ethernet1
   switchport access vlan 10
   spanning-tree portfast
   spanning-tree bpduguard enable
   switchport port-security
   switchport port-security maximum 2
!
interface Ethernet48
   ip dhcp snooping trust
   ip arp inspection trust
   spanning-tree guard root
```

Scoring (8):
- 2 — snooping enabled globally **and** for VLAN 10
- 2 — **trust on Ethernet48 only**; Ethernet1 left untrusted (the default). Trust stated on
  the wrong port scores 0 for this item.
- 1 — `ip arp inspection vlan 10` plus trust on the uplink
- 1 — `switchport port-security maximum 2` on **Ethernet1**
- 2 — **the two different STP protections on the two different ports**: PortFast +
  BPDU Guard on **Ethernet1**, Root Guard on **Ethernet48**. Both on the same port, or
  BPDU Guard on the uplink, scores 0 — BPDU Guard on a trunk would err-disable the uplink
  the instant the distribution switch sent its first BPDU.

*Exact EOS keyword spellings vary by release; accept close equivalents.*

**Trust boundary reversed:** you get **both** failures at once — a rogue DHCP server on
Ethernet1 is now trusted and free to serve addresses, **and** every legitimate DHCP
offer arriving from the real server via the untrusted uplink is dropped, so nobody on the
VLAN can get an address at all. The second half is what makes it obvious in about ninety
seconds.

### C3 (7) — eAPI idempotent change

```python
PEER   = "10.1.12.2"          # r2, from r1's perspective
PREFIX = "10.0.0.1/32"

# 1. READ — structured data, not screen scraping
state = eapi(r1, ["show bgp ipv4 unicast"], format="json")
advertised = state["vrfs"]["default"]["bgpRouteEntries"]

if PREFIX in advertised:                       # <-- IDEMPOTENCE CHECK
    changed = False
else:
    eapi(r1, ["configure",
              "router bgp 65001",
              "address-family ipv4",
              f"network {PREFIX}"])
    changed = True

# 2. VERIFY LOCALLY — necessary, not sufficient
local_ok = PREFIX in eapi(r1, ["show bgp ipv4 unicast"],
                          format="json")["vrfs"]["default"]["bgpRouteEntries"]

# 3. VERIFY FROM THE OTHER END — the real test    <-- VERIFICATION
peer_view = eapi(r2, ["show bgp ipv4 unicast"], format="json")
peer_ok   = PREFIX in peer_view["vrfs"]["default"]["bgpRouteEntries"]

return {"changed": changed,
        "drift":   not (local_ok and peer_ok),
        "local":   local_ok,
        "peer":    peer_ok}
```

Scoring (7):
- 2 — reads structured JSON via `format="json"` and indexes into it. Any use of regex or
  string matching over CLI text scores 0 for this item; that is the habit the lab exists to
  break.
- 2 — a real idempotence check that **skips the write** and reports `changed: False`.
  Sending the command unconditionally and merely reporting "no change" scores 1.
- 2 — verification **on r2**, checking that r2 actually **received** the prefix. Checking
  only r1 scores 0 here: the whole point is that a `network` statement can commit perfectly
  on r1 and never reach r2 because of a policy, a filter, RFC 8212 default-deny, or a
  session that is not established.
- 1 — a structured drift result the caller can branch on.

**If verification fails after a successful commit:** do **not** report success. Report
`changed: True, drift: True` with both observations attached, and either roll back to the
captured prior state or halt and escalate. "The commit returned 200 OK" is not the success
criterion — the peer's view is. A candidate who says the script should retry the same
commit has missed it: re-committing an already-committed change cannot fix a peer-side
problem.

---

## Section 4 — Design & trade-offs (15)

### D1 (8)

(a) *(3 — 1 each)*
- **Collapsed core:** L2/L3 boundary at the **collapsed core/distribution pair**. Gateway =
  **SVIs on that pair, fronted by VRRP**. Access switches are pure L2; STP runs between
  access and the pair.
- **Three-tier:** boundary at the **distribution layer**. Gateway = **SVIs on each
  distribution pair with an FHRP**; the core is pure L3 transit between distribution blocks,
  so STP is contained inside each access-distribution block and never crosses the core.
- **Routed access:** boundary at the **access switch itself**. Every access switch is a
  router; the gateway is a **local SVI/routed interface on that switch**, and uplinks are
  **routed point-to-point links running OSPF + BFD** — no FHRP across the uplink at all.

(b) *(3)* **Gain:** no spanning tree in the access layer — no L2 loops, no blocked uplinks
(all links forward with ECMP), and convergence driven by **IGP + BFD in sub-second** time
rather than STP and FHRP timers. Failure domains shrink to a single closet and
troubleshooting becomes a routing problem instead of a topology-guessing problem.

**Give up (two concrete things):**
1. **VLANs cannot span access switches.** Any application needing L2 adjacency across
   closets or buildings — legacy clustering, some appliances, silent hosts, certain
   discovery protocols — simply cannot be accommodated.
2. **More subnets, more routing state, more capable hardware.** A subnet per closet means a
   real address plan and summarisation discipline, every access switch needs L3-capable
   hardware and often licensing, and the operational skill floor rises from "VLANs" to
   "IGP design".

(c) *(2)* The stretched-VLAN requirement **rules out routed access** outright. Choose
**three-tier**: a distribution pair per building with an L3 core between them — 900 users
across three buildings justifies the distribution layer, and the design keeps each
building's STP domain to itself.

**What the legacy requirement costs:** that one VLAN must be carried as **L2 between two
buildings**, so the spanning-tree domain — and therefore the failure domain — now crosses a
building boundary. A broadcast storm or STP misconvergence in one building takes the other
with it, and STP blocks one of the inter-building links, so you pay for capacity you cannot
use. Worth full marks with a mitigation: carry that single VLAN over the L3 core as a
**VXLAN/EVPN overlay** instead, keeping everything else routed and confining the L2 domain
to a tunnel rather than a physical path.

### D2 (7)

(a) *(3 — 1 each)*
1. **"Was there a link flap between 02:40 and 02:50?" → syslog.** It is the only mechanism
   that records the discrete event with a timestamp. SNMP polling would only catch it if the
   flap happened to straddle a poll; NetFlow and SPAN show traffic, not interface state.
2. **"Which host consumed the WAN at 02:45?" → NetFlow.** Only per-flow records give
   **per-host attribution**. SNMP gives the interface total but cannot tell you who; syslog
   has no traffic data; SPAN would have it only if you happened to be capturing then and
   stored it.
3. **"What exactly did the malformed request contain?" → SPAN / packet capture.** The only
   mechanism with **payload**. NetFlow deliberately discards it, syslog has only whatever
   the application chose to log, SNMP has nothing.

(b) *(2)* **SPAN.** It duplicates the entire traffic volume onto a monitor port and a
collector, so it oversubscribes both the mirror port and the storage — you cannot mirror
everything everywhere continuously. Deploy it at a **few chokepoints** (DMZ, internet edge,
inter-VLAN boundary) using a tap or aggregator, keep a **rolling ring buffer** with an
explicit retention limit at those points (the model `soc-arkime-pcap` uses), and keep the
ability to enable a **targeted, filtered SPAN on demand** everywhere else.

(c) *(2)* Syslog is **UDP, fire-and-forget**: messages are dropped silently under load, and
— the vicious part — **if the device loses its path to the collector, the very event you
need is the one that never arrives**. A link flap can be its own cover-up. Unsynchronised
clocks compound it by making cross-device correlation impossible.

**Mitigation:** syslog over **TCP/TLS with local buffering** so messages survive a transient
outage and are retransmitted, **redundant collectors reachable over diverse paths**, and
**NTP everywhere** so timestamps from different devices can actually be correlated.

---

## Section 5 — Troubleshooting narrative (10)

### C-E4 — model answer

**1. Read the symptom (3).** The strongest answer argues these are **two presentations of
one root cause**, and says why:
- *"Drops after ~60 s of inactivity"* is the signature of a **stateful device idle
  timeout** — a firewall, NAT, or inspection appliance ages the session out of its table, and
  the next packet on that flow is dropped as out-of-state.
- *"New sessions sometimes fail"* points at **non-deterministic path selection** — ECMP or
  policy sends some flows down a path that bypasses the state-holding device (or reaches a
  second appliance with no state for them), so those flows fail from the first packet while
  their neighbours succeed.

Both are the same underlying condition: **the path and the state do not agree.** The new
appliance introduced a device that *requires* flow symmetry into a path that never had to
provide it. A well-argued "two separate faults" answer can score up to 2; the unified answer
scores 3.

**2. Three pieces of evidence, three layers (3).** *(1 each; must state what it shows under
the hypothesis.)*
- **Routing/control plane** — on the on-prem edge, the BGP table for the cloud prefixes and,
  as far as you can see it, the reverse. *Under the hypothesis:* two viable paths where you
  assumed one, or a return path preferring a route that does not traverse the appliance.
- **State** — the appliance's session/conntrack table for a specific failing 5-tuple, plus
  its configured idle timeouts. *Under the hypothesis:* either an entry with a ~60 s idle
  timer for that protocol, or — for the failing-from-the-start flows — **no entry at all**,
  which is the more damning finding.
- **Packet** — simultaneous captures on the appliance's inside and outside interfaces and at
  the edge, following one failing flow. *Under the hypothesis:* the outbound SYN visible at
  the appliance and the SYN-ACK **never appearing there**, having taken the other path.

**3. Why "nothing changed on the cloud side" is consistent (1).** Because the change was
**on-prem**, and what changed was not the routing — it was the **requirement**. The cloud is
selecting its return path exactly as it always has; that path was previously fine because
nothing on it needed to see both directions. Installing a stateful appliance retroactively
made a pre-existing, harmless asymmetry fatal. The cloud side is behaving identically and is
still where the packets die.

**4. Most likely cause, as a mechanism (2).** **Stateful inspection in an asymmetric path:**
flows traverse the appliance in one direction only, so it either never builds state (new
sessions fail) or builds state that nothing refreshes (idle timeout kills established
sessions), and out-of-state packets are dropped. Award 0 for "the firewall is broken" or
"the appliance is misconfigured" — the question asks for a mechanism and those name a
component.

**5. Fix and verification (1).** **Fix:** force symmetry — adjust routing/BGP policy (or
PBR) so both directions traverse the same stateful device, or place the appliance where it
is topologically unavoidable, or run the pair with **session-state synchronisation** so
either box can handle the reply. Separately, align the idle timeout with the application's
keepalive interval.

**Verification that rules out coincidence** — this is the graded half:
- Prove the mechanism, not the symptom: simultaneous captures showing **both directions of
  one flow now traversing the appliance**.
- Hold a session **deliberately idle past the old 60 s threshold** — five minutes, repeated
  — and show it survives.
- Open **dozens of new sessions** so every ECMP hash bucket is exercised, and show 100%
  succeed. "Sometimes fails" means one successful test proves nothing at all, and a
  candidate who retests once and declares victory should lose this point outright.

---

## Remediation table

| Question | Topic | Lab |
|---|---|---|
| C1, C2, C6, C-E1 | Access-layer hardening, uRPF, 802.1X | `labs/enterprise-access-security`, `labs/urpf-antispoofing`, `labs/dot1x-nac`, `labs/dot1x-ceos-practice` |
| C3, C4, C-E2 | DSCP, HTB, WRED, SFQ | `labs/qos-enterprise` |
| C5, C-E3 | L4/L7 balancing, XFF, asymmetric return | `labs/load-balancer-basics`, `labs/service-ha` |
| C7, D2 | SNMP, syslog, SPAN, NetFlow | `labs/network-assurance`, `labs/telemetry-monitoring-hybrid`, `labs/packet-analysis-basics` |
| C8, C3 (§3) | Idempotence, eAPI, verification | `labs/automation-fundamentals`, `labs/network-automation-netbox` |
| C9, C1 (§3), C-E1 | NAT ordering, conntrack, nftables policy | `labs/enterprise-edge-nat-firewall`, `labs/enterprise-dmz`, `labs/enterprise-dmz-capstone` |
| C10 | VRRP vs HSRP/GLBP | `labs/vrrp`, `labs/ha-network-design-ceos` |
| C2 (§3) | cEOS access hardening syntax | `labs/enterprise-access-security`, `labs/campus-l2-hardening` |
| D1 | Campus design comparison | `labs/enterprise-collapsed-core`, `labs/enterprise-campus`, `labs/enterprise-routed-access` and their capstones |
| C-E4 | Hybrid asymmetry, stateful path | `labs/cloud-hybrid-networking`, `labs/troubleshooting-range-advanced` |
