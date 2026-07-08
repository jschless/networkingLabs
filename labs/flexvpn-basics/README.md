# FlexVPN Basics — IKEv2 + VTI — Practice Lab

FlexVPN is Cisco's IKEv2 framework; this lab implements its concepts on
Linux with strongSwan and kernel VTI interfaces — route-based IPsec where
the *routing table*, not per-subnet policies, decides what gets encrypted.
The hub (gw-a) is fully pre-built. You bring up two spokes, tie VTIs to
IPsec SAs via XFRM marks, prove the encryption on the wire, and confirm
the hub-and-spoke forwarding model.

## How to use this lab

This is a **practice lab**, not a tutorial. The hub (gw-a) is fully
pre-configured; you build the spokes.

- **Predict before you configure**, **open hints before the solution**,
  and **verify** with `ipsec status`, `ip xfrm state`, and a WAN capture.

## Background

| Concept | Cisco FlexVPN | This lab (Linux + strongSwan) |
|---|---|---|
| Key exchange | IKEv2 (RFC 7296) | `keyexchange=ikev2` |
| Tunnel interface | Virtual-Access (SVTI) | `vti0/vti1/vti2` (ip_vti) |
| Per-spoke interface on hub | one Virtual-Access each | one VTI each |
| Routing | OSPF/BGP over tunnel | static or OSPF over VTI |
| Spoke-to-spoke | via hub (no NHRP) | via hub (no NHRP) |

A **VTI** is a point-to-point interface bound to an IPsec SA via a kernel
XFRM **mark**: route a packet into the VTI and it's encrypted by the
matching SA — no per-subnet XFRM policies. That's "route-based" IPsec, and
it's why routing protocols can run straight over the tunnel. Contrast
DMVPN, where NHRP creates dynamic spoke-to-spoke shortcuts; FlexVPN's
static VTIs always route spoke-to-spoke through the hub.

IKEv2 (vs IKEv1): 4 messages to establish (vs 9), built-in NAT traversal
and dead-peer detection, simpler rekeying, mandatory cipher agility.

## Topology

```mermaid
flowchart TB
    ha(["host-a\n192.168.1.10"])
    gwa["gw-a (HUB)\n192.168.1.1\n203.0.113.1\nvti1: 10.10.1.1\nvti2: 10.10.2.1"]
    inet["internet\n203.0.113.2 / .5 / .9"]
    gwb["gw-b (spoke1)\n203.0.113.6\n192.168.2.1\nvti0: 10.10.1.2"]
    gwc["gw-c (spoke2)\n203.0.113.10\n192.168.3.1\nvti0: 10.10.2.2"]
    hb(["host-b\n192.168.2.10"])
    hc(["host-c\n192.168.3.10"])

    ha -- "192.168.1.0/24" --- gwa
    gwa -- "203.0.113.0/30" --- inet
    inet -- "203.0.113.4/30" --- gwb
    inet -- "203.0.113.8/30" --- gwc
    gwb -- "192.168.2.0/24" --- hb
    gwc -- "192.168.3.0/24" --- hc

    gwa -. "IKEv2 VTI\n10.10.1.0/30" .- gwb
    gwa -. "IKEv2 VTI\n10.10.2.0/30" .- gwc

    classDef hub    fill:#8b4513,color:#fff,stroke:#000
    classDef spoke  fill:#4682b4,color:#fff,stroke:#000
    classDef router fill:#1a1aff,color:#fff,stroke:#000
    classDef host   fill:#3d7a3d,color:#fff,stroke:#000
    class gwa hub
    class gwb,gwc spoke
    class inet router
    class ha,hb,hc host
```

| Node | WAN | LAN | VTI |
|------|-----|-----|-----|
| gw-a (hub) | 203.0.113.1 | 192.168.1.1/24 | vti1 10.10.1.1, vti2 10.10.2.1 |
| gw-b (spoke1) | 203.0.113.6 | 192.168.2.1/24 | vti0 10.10.1.2 |
| gw-c (spoke2) | 203.0.113.10 | 192.168.3.1/24 | vti0 10.10.2.2 |

The PSK is `FlexVPN-SharedKey-2024`; `ipsec.secrets` is pre-populated on
the spokes.

## Deploy

```bash
docker build -t ipsec-lab:local labs/ipsec-basics/    # shared image, once
./scripts/lab.sh deploy flexvpn-basics
./scripts/lab.sh bash flexvpn-basics gw-a    # gw-b, gw-c
```

---

## Task 1 — Read the hub and understand VTI ↔ XFRM marks

**Objective:** Confirm WAN reachability and inspect how the hub's VTIs are
keyed, before any spoke connects.

```bash
./scripts/lab.sh cmd flexvpn-basics gw-a ping -c2 203.0.113.6
./scripts/lab.sh cmd flexvpn-basics gw-a ip tunnel show
./scripts/lab.sh cmd flexvpn-basics gw-a ip xfrm state    # empty so far
```

**Predict first:** the hub's `ip tunnel show` lists `vti1 ... key 1` and
`vti2 ... key 2`, but `ip xfrm state` is empty. How can a VTI exist with
no IPsec SA behind it yet — what does "key 1" do, and what installs the
actual encryption state?

<details markdown="1">
<summary>Check your work</summary>

The VTIs exist as plain interfaces with a `key` (kernel mark) but no SA —
`ip xfrm state` is empty because no spoke has negotiated yet. When a spoke
connects, strongSwan (with `mark=%unique`) installs XFRM SAs whose mark
matches the VTI's key, and the kernel then auto-encrypts anything routed
into that VTI. So the VTI is just a marked conduit; the IKEv2 negotiation
supplies the crypto. This decoupling — interface always present, SA comes
and goes — is what makes route-based IPsec resilient and routable.

</details>

---

## Task 2 — Build spoke1 (gw-b): VTI + IKEv2

**Objective:** On gw-b, create `vti0` (key 1, matching the hub's vti1),
address it, disable XFRM policy on it, uncomment the `to-hub` connection,
and start strongSwan until the SA is ESTABLISHED.

**Predict first:** the VTI `key` on gw-b must be `1` to match the hub's
vti1. What breaks if you use key 2 instead — does IKEv2 fail to
authenticate, or does the SA come up but traffic not flow?

<details markdown="1">
<summary>Hints</summary>

- `ip tunnel add vti0 mode vti local 203.0.113.6 remote 203.0.113.1 key 1`,
  then `ip link set vti0 up`, `ip addr add 10.10.1.2/30 dev vti0`,
  `sysctl -w net.ipv4.conf.vti0.disable_policy=1`.
- Uncomment `conn to-hub` in `/etc/ipsec.conf` (leftid `@spoke1`, rightid
  `@hub`, `mark=%unique`, `auto=start`).
- `ipsec start`; watch `tail -f /var/log/syslog` for `IKE_SA_INIT` /
  `IKE_AUTH`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
ip tunnel add vti0 mode vti local 203.0.113.6 remote 203.0.113.1 key 1
ip link set vti0 up
ip addr add 10.10.1.2/30 dev vti0
sysctl -w net.ipv4.conf.vti0.disable_policy=1
```

In `/etc/ipsec.conf`:
```
conn to-hub
    left=203.0.113.6
    leftid=@spoke1
    leftsubnet=0.0.0.0/0
    right=203.0.113.1
    rightid=@hub
    rightsubnet=0.0.0.0/0
    mark=%unique
    type=tunnel
    auto=start
```

Then `ipsec start`.

</details>

<details markdown="1">
<summary>Check your work</summary>

`ipsec status` shows `to-hub[1]: ESTABLISHED`; `ip xfrm state` shows two
ESP SAs (in + out) with a non-zero mark; `ping -c3 10.10.1.1` (hub VTI)
works and `tcpdump -i eth1 esp` shows ESP during the ping.

Prediction answer: a wrong VTI key is *not* an IKEv2 problem — the IKEv2
SA still authenticates and ESTABLISHES (it's keyed off `leftid`/`rightid`
and the PSK). But the kernel mark won't match, so encrypted traffic has no
SA to ride and pings fail. "SA established but pings dead" almost always
means a mark/route/disable_policy issue, not an IKE one — a crucial triage
split (compare ipsec-basics, where the failure modes are IKE-side).

</details>

---

## Task 3 — Route over the VTI

**Objective:** Add routes so gw-b reaches LAN A (and later spoke2's LAN)
via the hub VTI, and the hub routes back to LAN B.

<details markdown="1">
<summary>Solution</summary>

On **gw-b**:
```bash
ip route add 192.168.1.0/24 via 10.10.1.1 dev vti0   # LAN A
ip route add 192.168.3.0/24 via 10.10.1.1 dev vti0   # spoke2 LAN (via hub)
```

On **gw-a** (hub):
```bash
ip route add 192.168.2.0/24 via 10.10.1.2 dev vti1
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`host-b → 192.168.1.10` succeeds; `traceroute -n 192.168.1.1` from gw-b
shows the hub VTI (10.10.1.1) as the hop. This is route-based IPsec in
action: you didn't write a single XFRM policy — adding an `ip route` to
the VTI was enough to make that traffic encrypted, because the VTI's mark
ties it to the SA. That's the whole appeal over policy-based IPsec
(ipsec-basics), where adding a protected subnet means editing selectors.

</details>

---

## Task 4 — Build spoke2 (gw-c)

**Objective:** Repeat for gw-c — VTI key `2` (matching hub vti2), address
10.10.2.2/30, the `to-hub` conn with `@spoke2`, and routes.

<details markdown="1">
<summary>Solution</summary>

```bash
ip tunnel add vti0 mode vti local 203.0.113.10 remote 203.0.113.1 key 2
ip link set vti0 up
ip addr add 10.10.2.2/30 dev vti0
sysctl -w net.ipv4.conf.vti0.disable_policy=1
# uncomment conn to-hub with left=203.0.113.10, leftid=@spoke2
ipsec start
ip route add 192.168.1.0/24 via 10.10.2.1 dev vti0
ip route add 192.168.2.0/24 via 10.10.2.1 dev vti0
# on gw-a:  ip route add 192.168.3.0/24 via 10.10.2.2 dev vti2
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`ping -c3 10.10.2.1` from gw-c works; both spokes now have established SAs
to the hub. The hub holds *two* VTIs and *two* SAs — one dedicated
interface per spoke, which is the FlexVPN model (contrast DMVPN's single
mGRE serving all spokes). This per-spoke interface is what makes
per-tunnel routing metrics and QoS easy, at the cost of N interfaces on
the hub.

</details>

---

## Task 5 — Prove the spoke-to-spoke hairpin (the FlexVPN limit)

**Objective:** From host-b reach host-c and trace the path.

**Predict first:** both spokes have SAs to the hub but *not* to each other.
When host-b talks to host-c, how many encryption/decryption operations
happen on the hub, and how many hops will the traceroute show?

```bash
./scripts/lab.sh cmd flexvpn-basics host-b ping -c3 192.168.3.10
# on gw-b:
traceroute -n 192.168.3.10
```

<details markdown="1">
<summary>What you should observe</summary>

The path is host-b → gw-b → [vti0 encrypt] → **gw-a decrypt + re-encrypt**
→ [vti2] → gw-c → host-c. The hub decrypts spoke1's traffic and
re-encrypts it for spoke2 — a full crypto round-trip *plus* the data
hairpins through the hub's location even if the spokes are physically
adjacent. This is FlexVPN/static-VTI's defining limitation versus DMVPN
Phase 2's NHRP shortcut (dmvpn-phase2 lab). It's the price of the
simpler, NHRP-free static model — fine for a few sites, painful for a
large any-to-any mesh.

</details>

---

## Reference

### strongSwan
```bash
ipsec start | stop | restart
ipsec status            # ESTABLISHED / CONNECTING
ipsec statusall         # ciphers, lifetimes, counters
ipsec up|down to-hub
tail -f /var/log/syslog # live IKEv2 logs
```

### VTI / XFRM
```bash
ip tunnel add vti0 mode vti local <src> remote <dst> key <N>
ip tunnel show ; ip tunnel del vti0
sysctl -w net.ipv4.conf.vti0.disable_policy=1
ip xfrm state ; ip xfrm policy ; ip xfrm monitor
```

### Traffic
```bash
tcpdump -i eth1 esp                       # encrypted on WAN
tcpdump -i eth1 'udp port 500 or udp port 4500'   # IKEv2
```

### OSPF over VTI (design)

Static routes work but don't scale; OSPF over the VTIs (point-to-point
network type, all VTI+LAN interfaces in area 0, hub as the natural center)
distributes routes as spokes come and go. The `ipsec-lab:local` image
lacks FRR, so this is design-only here — but the network type matters:
point-to-point avoids DR/BDR election that a VTI can't complete.

---

## Challenge questions

No answers provided — reason them through.

1. The Task 5 hairpin does two crypto operations on the hub per spoke-to-
   spoke packet. Quantify the hub CPU and latency cost as spoke count and
   inter-spoke traffic grow, and explain exactly what DMVPN Phase 2's NHRP
   shortcut changes to avoid it.
2. A spoke's SA is ESTABLISHED but pings to the hub VTI fail. Give the
   ordered three-check diagnosis (mark match, route, `disable_policy`) and
   explain why none of these is an IKEv2 problem.
3. `mark=%unique` assigns a distinct mark per connection. Why is uniqueness
   essential when one hub terminates many spokes, and what breaks if two
   spokes accidentally share a mark/key?
4. You must add a 50th spoke. Compare the incremental work and hub state
   for FlexVPN (per-spoke VTI) vs DMVPN (one mGRE + NHRP registration), and
   state the spoke count where you'd switch designs.

## Troubleshooting

**Tunnel stuck CONNECTING** — verify WAN reachability first; both sides
running `ipsec`; read `/var/log/syslog`; confirm the conn block is
uncommented.

**AUTH_FAILED** — `leftid`/`rightid` are the PSK lookup keys; they must
match across `ipsec.conf` and `ipsec.secrets` on both ends.

**ESTABLISHED but pings fail** — check two SAs in `ip xfrm state`, routes
exist, and `disable_policy=1` on the VTI; capture `vti0` and `eth1`
together while pinging.

**`RTNETLINK answers: File exists`** — a stale VTI; `ip tunnel del vti0`
then recreate.

## Extensions

Optional follow-on ideas (not part of the validated workflow):

- Add a routing protocol over the VTI and compare to the static base.
- Replace PSK with certificates; note which strongSwan identities change.
- Force a proposal or mark mismatch and isolate it with `ip xfrm` +
  `ipsec statusall` + capture.
