# Topic Quiz — Data-Center EVPN

**Time:** 40 minutes · **Total:** 30 points · **Closed book, no CLI**

**Prerequisites:** `spine-leaf`, `vxlan-evpn`, `evpn-border-ceos`, and
`dci-evpn-multisite`.

Configuration syntax is Arista EOS as used by the labs.

---

## Section 1 — Mechanisms (6 points)

### A1 — Route types enable different traffic (3 points)

For EVPN route types 2, 3, and 5, state what each carries and one symptom expected when
that type is missing. (3 pts)

### A2 — Attributes that must survive the spine (3 points)

Explain why an eBGP EVPN spine uses `next-hop-unchanged`, why leaves must send extended
communities, and why RDs may differ per leaf while RTs must match for a shared tenant.
(3 pts)

---

## Section 2 — Evidence reading (8 points)

### B1 — Visible NLRI, empty tenant RIB

```text
a-leaf# show bgp evpn route-type ip-prefix 10.20.0.0/24
Route Distinguisher: 10.20.0.1:50010
Route Target: 65020:50010
Next Hop: 10.20.0.1
Valid, best

a-leaf# show ip route vrf PROD 10.20.0.0/24
% Network not in table

a-leaf# show running-config section router bgp
router bgp 65011
   vrf PROD
      rd 10.10.0.1:50010
      route-target import evpn 65020:59999
      route-target export evpn 65010:50010
```

Underlay reachability to the remote VTEP and the EVPN session are healthy.

1. Explain why the route is visible globally but absent from the PROD RIB. (3 pts)
2. Give the minimal repair and explain why changing the RD would not repair import.
   (2 pts)
3. State three post-change checks spanning control plane, tenant RIB, and data plane.
   (3 pts)

---

## Section 3 — Application (10 points)

### C1 — One tenant on one leaf

Complete the relevant EOS BGP stanzas for leaf1:

- local AS 65001;
- EVPN peers `10.1.0.1` AS 65100 and `10.2.0.1` AS 65200;
- extended communities sent to both peers and both activated under EVPN;
- VLAN 10 uses automatic RD, RT `65000:10010`, and exports learned MACs;
- VRF TENANT-A uses RD `10.0.0.1:50001`, imports and exports RT
  `65000:50001`, and advertises connected prefixes.

The IPv4 underlay and Vxlan1 mappings already exist.

---

## Section 4 — Design and troubleshooting (6 points)

### D1 — Route between sites or stretch Layer 2?

Two sites need PROD connectivity, but failure containment and DEV isolation matter more
than preserving a subnet during VM mobility. Defend a routed type-5 DCI over an L2
extension. Include the route-target policy, expected effect of a DCI failure, and evidence
that distinguishes a wrong import RT from an unreachable remote VTEP. (6 pts)

---

*End of Data-Center EVPN quiz. Key:
[`../answer-keys/quizzes/evpn-key.md`](../answer-keys/quizzes/evpn-key.md).*
