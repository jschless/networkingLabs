# MPLS SR + IS-IS + BGP L3VPN — Practice Lab (reference build)

A complete modern Service Provider stack, working out of the box:
IS-IS Level-2 as the IGP, **Segment Routing MPLS** for labels (no LDP),
BGP VPNv4 with a Route Reflector for L3VPN, and CE routers doing eBGP with
the PEs. This is a *reference* lab — nothing to configure. Your job is to
trace how the four layers stack, predict what each `show` will reveal, and
prove the label stack with your own eyes.

## How to use this lab

This is a **practice lab** built on a working reference topology. You won't
configure it — you'll *interrogate* it.

- **Predict before each command**: commit to what the output will show
  before you run it.
- **Open the explanation only after** you've looked, to check your
  reasoning.

## Topology

```mermaid
flowchart TB
    rr1["rr1\n10.0.0.1/32\nSID 1 · label 16001\nAS65000 RR"]
    p1["p1\n10.0.0.4/32\nSID 4 · label 16004"]
    p2["p2\n10.0.0.5/32\nSID 5 · label 16005"]
    pe1["pe1\n10.0.0.2/32\nSID 2 · label 16002"]
    pe2["pe2\n10.0.0.3/32\nSID 3 · label 16003"]
    ce1(["ce1\n10.0.0.6/32\nAS65001"])
    ce2(["ce2\n10.0.0.7/32\nAS65002"])

    p1 --- |"10.1.0.4/30"| rr1
    rr1 --- |"10.1.0.8/30"| p2
    p1 --- |"10.1.0.12/30"| p2
    pe1 --- |"10.1.0.0/30"| p1
    p2 --- |"10.1.0.16/30"| pe2
    ce1 --- |"192.168.10.0/30"| pe1
    ce2 --- |"192.168.20.0/30"| pe2

    classDef pe fill:#5c2d91,color:#fff,stroke:#000
    classDef p  fill:#7a3b00,color:#fff,stroke:#000
    classDef rr fill:#8b0000,color:#fff,stroke:#000
    classDef ce fill:#006400,color:#fff,stroke:#000
    class rr1 rr
    class p1,p2 p
    class pe1,pe2 pe
    class ce1,ce2 ce
```

| Node | Loopback | SR SID | SR Label | Role |
|------|----------|--------|----------|------|
| rr1  | 10.0.0.1/32 | 1 | 16001 | BGP RR + P |
| pe1  | 10.0.0.2/32 | 2 | 16002 | PE |
| pe2  | 10.0.0.3/32 | 3 | 16003 | PE |
| p1   | 10.0.0.4/32 | 4 | 16004 | P |
| p2   | 10.0.0.5/32 | 5 | 16005 | P |
| ce1  | 10.0.0.6/32 | — | — | CE (AS65001) |
| ce2  | 10.0.0.7/32 | — | — | CE (AS65002) |

## Deploy

```bash
./scripts/lab.sh deploy mpls-sr-isis-bgp   # wait 30–60s to converge
./scripts/lab.sh cli mpls-sr-isis-bgp pe1
```

---

## Task 1 — Derive the SR label, then confirm it

**Objective:** Without looking, compute pe2's SR-MPLS label from its SID,
then verify in the MPLS table.

**Predict first:** the SRGB starts at 16000 and pe2 has Node SID 3. What
label will *any* node push to forward toward pe2's loopback? Write it down,
then check.

```bash
./scripts/lab.sh cmd mpls-sr-isis-bgp pe1 -- vtysh -c "show mpls table"
./scripts/lab.sh cmd mpls-sr-isis-bgp pe1 -- vtysh -c "show segment-routing local-block"
```

<details markdown="1">
<summary>Check your work</summary>

Label = SRGB_start + SID = 16000 + 3 = **16003**. The whole elegance of
SR-MPLS is here: the label is *derived deterministically* from a globally
agreed SRGB plus a per-node index advertised in IS-IS — no LDP, no
per-LSP signaling, no per-hop label state to maintain. Compare LDP, where
each router picks arbitrary local labels and signals them hop by hop. The
SRGB (`local-block` output) is the shared label range that makes the
arithmetic work network-wide.

</details>

---

## Task 2 — Prove the L3VPN end to end and read the label stack

**Objective:** Ping ce1 → ce2 across the L3VPN, then trace and reason about
the two-label stack pe1 imposes.

**Predict first:** the customer packet from ce1 to ce2 crosses the SP core.
How many MPLS labels will pe1 push, what does each one do, and which router
removes which label?

```bash
./scripts/lab.sh cmd mpls-sr-isis-bgp ce1 -- ping -c3 10.0.0.7
./scripts/lab.sh cmd mpls-sr-isis-bgp rr1 -- vtysh -c "show bgp ipv4 vpn"
./scripts/lab.sh cmd mpls-sr-isis-bgp pe1 -- vtysh -c "show ip route vrf CUST-A"
```

<details markdown="1">
<summary>Check your work</summary>

pe1 pushes **two** labels: an outer **SR transport label (16003)** to get
the packet to pe2, and an inner **VPN label** that tells pe2 which
VRF/CE to deliver to:

```
[VPN label] [SR 16003] [IP]
```

P routers swap only the outer SR label as the packet travels toward pe2;
at the penultimate hop (p2) PHP pops the SR label (implicit null), so pe2
receives just `[VPN label][IP]`, reads the VPN label, and forwards into
CUST-A toward ce2. This two-label "transport + service" separation is the
core idea of MPLS L3VPN — the core only needs to know *transport* labels,
never customer routes. The RD (65000:100) in `show bgp ipv4 vpn` is what
keeps customer prefixes unique even across overlapping address space.

</details>

---

## Task 3 — Break it: raise an IGP metric, watch SR follow

**Objective:** Make the p1–p2 link expensive in IS-IS and observe whether
the SR forwarding path moves.

**Predict first:** SR labels are derived from IS-IS, and IS-IS runs SPF.
If you raise the p1–p2 metric, does the *label* for pe2 change, does the
*path* the label follows change, or both?

```bash
# raise the metric on p1's link toward p2, then re-check the path
./scripts/lab.sh cmd mpls-sr-isis-bgp ce1 -- traceroute -n 10.0.0.7
```

<details markdown="1">
<summary>What you should observe</summary>

The label for pe2 stays **16003** (it's tied to pe2's SID, not the path),
but the *path that label follows* re-routes around the expensive link,
because SR forwarding rides the IGP's SPF result. This is the key SR
property: the label names a *destination*, and the IGP decides the route —
so a topology change reconverges SR automatically with no label
re-signaling (unlike LDP, which would have to redistribute new bindings).
SR-TE would let you override SPF by pushing a *stack* of SIDs to pin an
explicit path. Restore the metric afterward.

</details>

---

## Architecture (reference)

**IS-IS L2** advertises every SP loopback. **SR-MPLS** distributes labels
via IS-IS TLVs (Node SID index N → label 16000+N) — no LDP, no per-hop
state. **BGP VPNv4 + RR**: rr1 reflects VPNv4 routes among PEs; RD
65000:100 makes routes unique, RT 65000:100 controls import/export.
**L3VPN**: PEs hold VRF `CUST-A` (table 100); CE routes are redistributed
into VPNv4 and imported into the remote VRF.

| Feature | LDP | SR-MPLS |
|---------|-----|---------|
| Label distribution | separate LDP sessions | IS-IS/OSPF extensions |
| Allocation | per-LSP, dynamic | per-prefix from SRGB |
| Transit state | per-hop | stateless |
| TE | RSVP-TE | SR-TE (source routing) |

---

## Challenge questions

No answers provided — reason them through.

1. Add a second VRF `CUST-B` (RD/RT 65000:200) on pe1/pe2. Explain
   precisely how the RD keeps CUST-A and CUST-B routes separate in BGP
   even if both customers use 192.168.10.0/30, and what the RT does that
   the RD does not.
2. Match a VPN label in `show bgp ipv4 vpn` on rr1 to an entry in `show
   mpls table` on pe2. Why is the *VPN* label locally significant to pe2
   while the *SR transport* label (16003) is globally meaningful?
3. SR removed LDP. Walk through what LDP would have had to do for the same
   ce1→ce2 path, and quantify the state/protocol savings SR provides on a
   100-router core.
4. The RR reflects VPNv4 routes but is also a P router in the data path.
   Argue whether co-locating RR and P is a good idea at scale, and what
   failure couples the control and data planes if you do.
