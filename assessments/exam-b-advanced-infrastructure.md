# Exam B — Advanced Infrastructure

**Time:** 2 hours · **Total:** 100 points · **Closed book, no CLI**

Covers the MPLS & Service Provider, Data Center, Tunnels & VPN, and High Availability
tracks.

Prerequisite knowledge: Exam A material is assumed, not re-tested. Where a question says
"FRR", write FRR syntax as used in `labs/mpls-sr-isis-bgp`; where it says "EOS", write
Arista syntax as used in `labs/vxlan-evpn`.

---

## Section 1 — Concepts & mechanisms (30 points)

Ten questions, 3 points each.

**B1.** Segment Routing replaces LDP in the `mpls-sr-*` labs. (a) Where does a node's MPLS
label come from — show the arithmetic that turns pe1's `segment-routing prefix 10.0.0.2/32
index 2` into the label 16002. (b) Name the two things SR removes from the network that
LDP required, and say what SR uses instead to distribute labels.

**B2.** Penultimate hop popping. What is the label value that signals it, which router
pops, and what problem does PHP solve for the egress router? State one thing PHP breaks or
complicates.

**B3.** In an MPLS L3VPN, both the route distinguisher and the route target are 8-byte
values configured per-VRF and both appear in `show bgp ipv4 vpn` output. Explain what each
one actually does, and answer specifically: if pe1 and pe2 use *different* RDs for the same
customer, does the VPN still work? Why?

**B4.** A packet travelling from ce1 to ce2 across the `mpls-sr-isis-bgp` core carries two
labels. Name each label, say **which router assigned it**, and describe what happens to the
stack at the penultimate P router and at the egress PE.

**B5.** EVPN route types. Describe what Type-2, Type-3, and Type-5 each carry and what
breaks if each one is missing. Then define the difference between symmetric and asymmetric
IRB, and state which one the `vxlan-evpn` lab builds and how you can tell from the config.

**B6.** The data-center track flags that `send-community extended` is **required** on every
eBGP neighbor in cEOS and is not automatic. Explain the failure precisely: what is carried
in an extended community that EVPN depends on, and what does the receiving leaf's table
look like when it is missing — no routes at all, or routes that are present but unusable?

**B7.** A CLOS underlay gives every leaf its own ASN and every spine its own ASN. Explain
why `bgp bestpath as-path multipath-relax` is needed for ECMP across two spines, and what
exactly the router does without it when the two paths have equal AS-path *length* but
different AS-path *content*.

**B8.** DMVPN phases. For each of Phase 1, 2, and 3: describe the data path a
spoke-to-spoke packet takes, state whether the hub may summarise the routing advertisement,
and name the NHRP mechanism that makes that phase's behaviour possible.

**B9.** A GRE tunnel runs over an underlay with MTU 1400. (a) Give the encapsulation
overhead in bytes and show the components. (b) State the largest inner IP packet that fits.
(c) Explain why a TCP transfer through this tunnel can hang completely while `ping` works
perfectly, and name the two configuration changes that fix it — say which one is the
belt and which the braces.

**B10.** BFD. (a) Why does BFD detect a failure faster than tuning OSPF or BGP hello/hold
timers to their minimums — what is structurally different? (b) What does BFD **echo mode**
test that asynchronous mode does not? (c) Give the reason aggressive BFD timers are a bad
idea specifically in these containerised labs.

---

## Section 2 — Evidence reading (20 points)

### B-E1 (7 points)

A customer VRF is not working end to end. On pe2:

```text
pe2# show bgp ipv4 vpn
   Network          Next Hop            Metric LocPrf Weight Path
Route Distinguisher: 65000:100
*>i10.100.1.1/32    10.0.0.2                 0    100      0 65001 i
```

```text
pe2# show ip route vrf CUST-A
VRF CUST-A:
C>* 192.168.20.0/30 is directly connected, eth2
```

```text
pe2# show bgp vrf CUST-A ipv4 unicast
No BGP prefixes displayed
```

(a) State precisely what is and is not working — be specific about which table the prefix
reached. (2 pts)
(b) Name the single most likely misconfiguration and the exact configuration item you would
inspect on pe2. (3 pts)
(c) Two other faults would produce an *empty VPNv4 table* on pe2 instead of what is shown
here. Name them, and explain why this output rules both out. (2 pts)

### B-E2 (7 points)

From `host-a` in the `mtu-pmtud-troubleshooting` topology. The GRE tunnel is up, routing is
correct, and the WAN links are MTU 1400.

```text
host-a:~$ ping -M do -s 1348 192.168.2.10
PING 192.168.2.10 (192.168.2.10) 1348(1376) bytes of data.
1356 bytes from 192.168.2.10: icmp_seq=1 ttl=62 time=1.44 ms

host-a:~$ ping -M do -s 1349 192.168.2.10
PING 192.168.2.10 (192.168.2.10) 1349(1377) bytes of data.
^C
--- 192.168.2.10 ping statistics ---
4 packets transmitted, 0 received, 100% packet loss
```

```text
host-a:~$ curl -m 10 http://192.168.2.10:8080/
curl: (28) Operation timed out after 10001 milliseconds with 0 bytes received
```

(a) Do the arithmetic. From the 1348/1349 boundary, derive the largest inner IP packet the
path accepts and then the correct `ip mtu` value for the tunnel interface. Show your
working. (3 pts)
(b) The `curl` fails while a 1348-byte ping succeeds. Explain the mechanism — include what
MSS the two ends negotiated and why. (2 pts)
(c) Path MTU Discovery is supposed to prevent exactly this. Give the reason it did not, and
name the fix that does not depend on PMTUD working at all. (2 pts)

### B-E3 (6 points)

In the `vxlan-evpn` fabric, host-a1 (leaf1) cannot reach host-a2 (leaf3), same tenant, same
subnet.

```text
leaf3# ping 10.0.0.1 source 10.0.0.3
5 packets transmitted, 5 received, 0% packet loss

leaf3# show bgp evpn route-type mac-ip
BGP routing table information for VRF default
          Network             Next Hop     Metric  LocPref Weight Path
 * >     RD: 10.0.0.3:10010 mac-ip 001c.7300.0003 10.10.10.12
                             -                    -       -      -  i
```

Underlay loopback reachability is proven. Only leaf3's own MAC appears; nothing from
leaf1. Rank three candidate causes from most to least likely, and for each give the one
command whose output would confirm or eliminate it.

---

## Section 3 — Implementation on paper (25 points)

### C1 (10 points) — FRR

Write the configuration for **pe1** in the `mpls-sr-blank` topology. Reference data:

- pe1 loopback `10.0.0.2/32`, NET `49.0001.0000.0000.0002.00`, SR index 2
- core-facing `eth2` → p1, `10.1.0.1/30`, IS-IS metric 10, point-to-point
- customer-facing `eth1` → ce1, `192.168.10.2/30`, in VRF `CUST-A`
- ce1 is AS 65001; the provider AS is 65000; rr1 at `10.0.0.1` is the route reflector
- RD and RT for the customer: `65000:100`

Include: the IS-IS instance with SR, the interface statements, the global BGP instance
with the VPNv4 session to the RR, and the VRF BGP instance with the eBGP session to ce1
and the import/export configuration.

Then state, outside the config, the **one topology-file setting** this lab requires that is
not part of any router config, why it must be set that way, and what breaks without it.

### C2 (8 points) — Arista EOS

Write the EVPN and VXLAN configuration for **leaf1** in `vxlan-evpn` for **TENANT-A only**
(ignore TENANT-B). Reference data:

- leaf1 AS 65001, loopback0 `10.0.0.1/32`
- spine1 `10.1.0.1` (AS 65100), spine2 `10.2.0.1` (AS 65200)
- TENANT-A: VLAN 10, L2VNI 10010, L3VNI 50001, subnet `10.10.10.0/24`, anycast gateway
  `10.10.10.1`
- host-a1 is on Ethernet3

Include the VRF, the anycast gateway, the Vxlan1 interface, the SVI, and the BGP
configuration with both EVPN instances. Two specific lines are worth double marks — a
candidate who omits them has a fabric that comes up and does not forward.

### C3 (7 points) — Concept-level configuration

Describe the configuration of a **DMVPN Phase 3** hub and one spoke. Platform-neutral
prose plus the key parameters is fine — you are graded on the elements, not the grammar of
any one vendor.

State for the **hub**: tunnel mode, NHRP role, the one NHRP command that distinguishes
Phase 3 from Phase 2, the routing protocol network type used in `dmvpn-phase3`, and whether
the hub may summarise.
State for the **spoke**: how it finds the hub, the NHRP command that lets it install a
shortcut, and what its routing table looks like before and after a spoke-to-spoke flow
starts.

---

## Section 4 — Design & trade-offs (15 points)

### D1 (8 points)

You must isolate two tenants that share physical infrastructure. Compare three approaches
this repo builds: **VRF-Lite hop-by-hop** (`vrf-lite`), **MPLS L3VPN** (`mpls-sr-blank`),
and **EVPN with Type-5 routes** (`vxlan-evpn`, `evpn-border-ceos`).

For each, state: what carries the tenant identity in the data plane, what has to be
configured on the *transit* devices, and how the configuration burden scales as you add the
eleventh tenant. Then give the deciding factor you would use to choose between L3VPN and
EVPN for a new build, and name one scenario where plain VRF-Lite is genuinely the right
answer.

### D2 (7 points)

The `ha-network-design-ceos` lab stacks MLAG, VRRP with tracking, OSPF with BFD, and
dual-ISP BGP in one design.

(a) For each of MLAG, VRRP, and BFD, state what failure it detects and roughly how fast.
(3 pts)
(b) VRRP tracking exists because VRRP on its own has a specific blind spot. Describe the
failure scenario where the VRRP master is healthy and still the wrong device to be master.
(2 pts)
(c) Name one way these mechanisms interact badly — a case where two of them together
produce an outcome neither would alone. (2 pts)

---

## Section 5 — Troubleshooting narrative (10 points)

### B-E4

**Symptom:** In an MPLS L3VPN, ce1 cannot ping ce2. You have already established:

- the VPNv4 route for ce2's prefix is present on pe1 **and** imported into VRF `CUST-A`
- `show ip route vrf CUST-A` on pe1 shows the remote prefix with the correct next-hop
  (pe2's loopback)
- the IGP is completely healthy: every router sees every loopback, no adjacency is down,
  and `ping` between pe1 and pe2 loopbacks succeeds

Structure your answer:

1. **What the healthy IGP tells you, and what it deliberately does not.** Why is a
   successful loopback-to-loopback ping *not* evidence that the LSP works? (3 pts)
2. **Three commands** that inspect the label plane rather than the IP plane, with what each
   would show in the healthy case. (3 pts)
3. **The most likely fault class** given everything that has been ruled out, and where in
   the path it lives. (2 pts)
4. **How you would localise it to a specific hop** without shutting anything down. (1 pt)
5. **Verification** after the fix — state a check that proves the *label* path, not just
   that the ping now works. (1 pt)

---

*End of Exam B. Key: [`answer-keys/exam-b-key.md`](answer-keys/exam-b-key.md).*
