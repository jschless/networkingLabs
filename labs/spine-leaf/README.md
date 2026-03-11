# BGP CLOS Spine-Leaf Fabric — Arista cEOS Practice Lab

Configure a BGP CLOS spine-leaf fabric using Arista EOS. Interface IP addressing is pre-configured; you implement eBGP sessions, ECMP, and multipath-relax on each node.

Arista is the dominant platform for data center spine-leaf fabrics. This lab uses the same `router bgp`, `maximum-paths ecmp`, and `bgp bestpath` commands used on production Arista switches.

---

## Topology

```
        [spine1]              [spine2]
        AS65100               AS65200
    /    |    |    \       /    |    |    \
   /     |    |     \     /     |    |     \
[leaf1][leaf2][leaf3][leaf4] (each leaf: dual uplinks)
AS65001 AS65002 AS65003 AS65004
```

### IP addressing (/31 subnets — DC standard)

| Link          | Subnet       | Leaf IP    | Spine IP   |
|---------------|--------------|------------|------------|
| leaf1–spine1  | 10.1.0.0/31  | 10.1.0.0   | 10.1.0.1   |
| leaf2–spine1  | 10.1.0.2/31  | 10.1.0.2   | 10.1.0.3   |
| leaf3–spine1  | 10.1.0.4/31  | 10.1.0.4   | 10.1.0.5   |
| leaf4–spine1  | 10.1.0.6/31  | 10.1.0.6   | 10.1.0.7   |
| leaf1–spine2  | 10.2.0.0/31  | 10.2.0.0   | 10.2.0.1   |
| leaf2–spine2  | 10.2.0.2/31  | 10.2.0.2   | 10.2.0.3   |
| leaf3–spine2  | 10.2.0.4/31  | 10.2.0.4   | 10.2.0.5   |
| leaf4–spine2  | 10.2.0.6/31  | 10.2.0.6   | 10.2.0.7   |

Loopbacks: spine1=10.0.0.101/32, spine2=10.0.0.102/32, leaf1-4=10.0.0.1-4/32

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/spine-leaf/topology.clab.yml

# EOS CLI
docker exec -it clab-spine-leaf-spine1 Cli
docker exec -it clab-spine-leaf-leaf1  Cli
```

---

## Step 1 — Configure spine1 (AS65100)

```bash
docker exec -it clab-spine-leaf-spine1 Cli
```

```
configure
router bgp 65100
   router-id 10.0.0.101
   maximum-paths 4 ecmp 4
   bgp bestpath as-path multipath-relax
   neighbor 10.1.0.0 remote-as 65001
   neighbor 10.1.0.2 remote-as 65002
   neighbor 10.1.0.4 remote-as 65003
   neighbor 10.1.0.6 remote-as 65004
   !
   address-family ipv4
      neighbor 10.1.0.0 activate
      neighbor 10.1.0.2 activate
      neighbor 10.1.0.4 activate
      neighbor 10.1.0.6 activate
      network 10.0.0.101/32
```

### Why these two settings matter

**`maximum-paths 4 ecmp 4`** — without this, EOS installs only one BGP path in the FIB even if multiple equal-cost paths exist. The first number controls BGP RIB multipath; the second controls FIB ECMP installation.

**`bgp bestpath as-path multipath-relax`** — in a CLOS fabric, routes learned from leaf1 and leaf2 have *different AS paths* (leaf1's loopback comes via AS65001, leaf2's via AS65002). Normally BGP requires identical AS paths for multipath. This command relaxes that requirement, allowing routes with different AS paths to share a load-balanced forwarding entry.

---

## Step 2 — Configure spine2 (AS65200)

```bash
docker exec -it clab-spine-leaf-spine2 Cli
```

```
configure
router bgp 65200
   router-id 10.0.0.102
   maximum-paths 4 ecmp 4
   bgp bestpath as-path multipath-relax
   neighbor 10.2.0.0 remote-as 65001
   neighbor 10.2.0.2 remote-as 65002
   neighbor 10.2.0.4 remote-as 65003
   neighbor 10.2.0.6 remote-as 65004
   !
   address-family ipv4
      neighbor 10.2.0.0 activate
      neighbor 10.2.0.2 activate
      neighbor 10.2.0.4 activate
      neighbor 10.2.0.6 activate
      network 10.0.0.102/32
```

---

## Step 3 — Configure leaf1 (AS65001)

```bash
docker exec -it clab-spine-leaf-leaf1 Cli
```

```
configure
router bgp 65001
   router-id 10.0.0.1
   maximum-paths 2 ecmp 2
   bgp bestpath as-path multipath-relax
   neighbor 10.1.0.1 remote-as 65100
   neighbor 10.2.0.1 remote-as 65200
   !
   address-family ipv4
      neighbor 10.1.0.1 activate
      neighbor 10.2.0.1 activate
      network 10.0.0.1/32
```

Repeat for leaf2–leaf4 with appropriate router-id, neighbor IPs, and AS numbers (see startup-config hints in `configs/leafX/startup-config`).

---

## Step 4 — Verify

Check BGP sessions on spine1:
```
show bgp summary
```

All 4 leaves should show `Estab` with non-zero prefixes received.

Check ECMP on spine1:
```
show ip route 10.0.0.1/32
```

Should show 2 equal-cost paths (one via each leaf uplink — wait, spine1 only connects to one leaf per link, so this may show one path per leaf loopback. But a leaf's loopback is reachable via both spines from another leaf's perspective).

Verify ECMP from a leaf perspective:
```
# On leaf1
show ip route 10.0.0.2/32
```

Should show 2 paths: via 10.1.0.1 (spine1) and 10.2.0.1 (spine2).

End-to-end reachability:
```
# On leaf1
ping 10.0.0.2 repeat 5     ← leaf2 loopback
ping 10.0.0.3 repeat 5     ← leaf3 loopback
ping 10.0.0.4 repeat 5     ← leaf4 loopback
ping 10.0.0.101 repeat 5   ← spine1 loopback
ping 10.0.0.102 repeat 5   ← spine2 loopback
```

---

## Experiment — Observe ECMP in action

Use extended ping from leaf1 to leaf4's loopback with traceroute:
```
traceroute 10.0.0.4 repeat 3
```

You should see the path alternating between spine1 and spine2 across multiple probes (EOS uses 5-tuple hashing by default).

Check ECMP forwarding table:
```
show ip route 10.0.0.4/32 detail
```

---

## Data Center Capstone (All-in-One)

Use this single topology as a full capstone, progressing from basic underlay to
multi-tenant EVPN/VXLAN design.

### Capstone Outcomes

By the end, you should be able to:
1. Build and troubleshoot eBGP CLOS underlay with ECMP.
2. Add operational hardening (BFD, guardrails, policy filters, peer-groups).
3. Segment tenants with VRFs and VLANs at leafs.
4. Run BGP EVPN control plane over the existing underlay.
5. Map VLANs to VNIs and validate VXLAN overlay reachability.
6. Explain control-plane and data-plane behavior during failures.

### Phase 1 — Underlay Foundation (Current Lab Core)

Scope:
1. Complete BGP on all spines/leaves.
2. Validate all sessions `Established`.
3. Validate ECMP for remote leaf loopbacks.

Exit criteria:
1. `show bgp summary` is healthy on every node.
2. `show ip route <remote-loopback>/32` shows expected next-hops.
3. Leaf-to-leaf loopback ping works with loopback source.

### Phase 2 — Underlay Hardening

Scope:
1. Enable BFD on all eBGP adjacencies.
2. Add `maximum-routes` guardrails per neighbor.
3. Add inbound prefix filtering to only accept expected loopback/service ranges.
4. Refactor repeated BGP config with peer-groups.

Suggested checks:
```
show bfd peers
show bgp neighbors
show running-config section router bgp
```

Failure drill:
```
# host shell example
docker exec clab-spine-leaf-leaf1 ip link set eth1 down
```
Measure session and route convergence before/after BFD.

### Phase 3 — Tenant Segmentation on Leafs (VRFs + VLANs)

Scope:
1. Create two tenant VRFs on each leaf (for example `TENANT_A`, `TENANT_B`).
2. Create VLANs and SVIs per tenant.
3. Place local test endpoints/subinterfaces into tenant VLANs.
4. Validate local L3 within each VRF before overlay.

Design target:
1. No route leakage between tenants unless explicitly configured.
2. Clean separation of routing tables per VRF.

Suggested checks:
```
show vrf
show ip route vrf TENANT_A
show ip route vrf TENANT_B
```

### Phase 4 — EVPN Control Plane

Scope:
1. Add VTEP loopback (`Loopback1`) on each leaf.
2. Advertise VTEP loopbacks in underlay IPv4 BGP.
3. Build BGP EVPN sessions (commonly leaf-to-spine RR model in larger fabrics).
4. Enable EVPN address-family neighbors and extended communities.

Control-plane checks:
```
show bgp evpn summary
show bgp evpn route-type mac-ip
```

### Phase 5 — VXLAN Data Plane

Scope:
1. Map tenant VLANs to L2 VNIs.
2. Configure VTEP source interface and VXLAN encapsulation on leaves.
3. (Optional) Add L3VNI per VRF for distributed inter-subnet routing.
4. Validate host reachability across leaves within the same tenant.

Data-plane checks:
```
show vxlan vni
show mac address-table dynamic
show arp vrf TENANT_A
```

### Phase 6 — Policy, Failure, and Operations

Scope:
1. Apply route-policy controls per tenant/VRF.
2. Validate behavior for link, spine, and leaf failure scenarios.
3. Document expected blast radius for each failure.
4. Capture operational runbook commands.

Suggested capstone drills:
1. Uplink loss on a leaf (ECMP path reduction, no outage expected).
2. Full spine failure (fabric continues through surviving spine).
3. Tenant route leak attempt (policy should block it).
4. BFD disable/enable comparison (convergence delta).

### Capstone Deliverables

1. Final addressing/ASN/VRF/VLAN/VNI table.
2. Per-node config snippets for underlay and overlay.
3. Verification evidence (command outputs + pass/fail notes).
4. Failure test report with observed convergence behavior.

### Suggested Companion Labs

1. `labs/debug-spine-leaf` for structured troubleshooting practice.
2. `labs/bfd-bgp` for deeper BFD behavior and timer tuning.
3. `labs/vrf-lite` for segmentation concepts before EVPN.
4. `labs/vxlan-evpn` as reference for full overlay build patterns.

---

## Guided Phase Snippets (Intentionally Incomplete)

These are starter templates, not final answer keys. Fill the TODOs and adapt per node.

### Phase 2 Snippet — Underlay Hardening

Leaf template:
```
configure
router bfd
   interval 300 min-rx 300 multiplier 3
!
router bgp <LEAF_ASN>
   neighbor <SPINE1_P2P_IP> bfd
   neighbor <SPINE2_P2P_IP> bfd
   neighbor <SPINE1_P2P_IP> maximum-routes 32 warning-only
   neighbor <SPINE2_P2P_IP> maximum-routes 32 warning-only
```

Spine template:
```
configure
ip prefix-list LEAF-LOOPS seq 10 permit 10.0.0.0/24 ge 32 le 32
route-map FROM-LEAFS-IN permit 10
   match ip address prefix-list LEAF-LOOPS
route-map FROM-LEAFS-IN deny 100
!
router bgp <SPINE_ASN>
   neighbor LEAFS peer group
   neighbor LEAFS remote-as external
   neighbor LEAFS route-map FROM-LEAFS-IN in
   ! TODO: bind each leaf neighbor IP to peer-group LEAFS
```

### Phase 3 Snippet — VRFs + VLANs on Leafs

```
configure
vrf instance TENANT_A
vrf instance TENANT_B
!
vlan 10
   name TENANT_A_APP
vlan 20
   name TENANT_B_APP
!
interface Vlan10
   vrf TENANT_A
   ip address 172.16.10.<LEAF_ID>/24
interface Vlan20
   vrf TENANT_B
   ip address 172.16.20.<LEAF_ID>/24
!
interface Ethernet3
   switchport access vlan 10
interface Ethernet4
   switchport access vlan 20
```

TODO ideas:
1. Pick an endpoint model (local host containers, subinterfaces, or just SVI reachability checks).
2. Decide if each leaf hosts both tenants or split tenants across leaf pairs.

### Phase 4 Snippet — EVPN Control Plane

Leaf template:
```
configure
interface Loopback1
   ip address 10.10.0.<LEAF_ID>/32
!
router bgp <LEAF_ASN>
   address-family ipv4
      network 10.10.0.<LEAF_ID>/32
   !
   neighbor <SPINE1_P2P_IP> send-community extended
   neighbor <SPINE2_P2P_IP> send-community extended
   !
   address-family evpn
      neighbor <SPINE1_P2P_IP> activate
      neighbor <SPINE2_P2P_IP> activate
```

Spine template:
```
configure
router bgp <SPINE_ASN>
   ! TODO: decide your EVPN peering model
   ! Option A: direct leaf-spine EVPN sessions in this small lab
   ! Option B: spine as RR pattern (closer to scale design)
   address-family evpn
      neighbor <LEAF_PEERS_OR_GROUP> activate
```

### Phase 5 Snippet — VXLAN + VNI Mapping

```
configure
interface Vxlan1
   vxlan source-interface Loopback1
   vxlan udp-port 4789
   vxlan vlan 10 vni 1010
   vxlan vlan 20 vni 1020
!
router bgp <LEAF_ASN>
   vlan 10
      rd auto
      route-target both 65000:1010
   vlan 20
      rd auto
      route-target both 65000:1020
```

Optional L3VNI direction:
```
router bgp <LEAF_ASN>
   vrf TENANT_A
      rd auto
      route-target import evpn 65000:11010
      route-target export evpn 65000:11010
   vrf TENANT_B
      rd auto
      route-target import evpn 65000:11020
      route-target export evpn 65000:11020
```

### Phase 6 Snippet — Policy + Failure Drills

Policy skeleton:
```
configure
ip prefix-list TENANT_A_ALLOWED seq 10 permit 172.16.10.0/24 le 32
route-map EVPN-TENANT-A-OUT permit 10
   match ip address prefix-list TENANT_A_ALLOWED
route-map EVPN-TENANT-A-OUT deny 100
```

Failure test examples:
1. Disable one leaf uplink and observe ECMP to single-path transition.
2. Disable one spine and validate control-plane/data-plane survival.
3. Introduce a bad prefix and verify policy blocks propagation.

---

## Troubleshooting

**BGP session stuck in `Active`**
- `show ip interface Ethernet1` — confirm interface is up and IP is correct
- `ping 10.1.0.1` from leaf1 — direct neighbor reachability
- Check AS numbers: each leaf must have the correct remote-as for the spine

**Routes not propagating**
- Confirm `network 10.0.0.x/32` is present under `address-family ipv4` and the loopback IP matches exactly
- `show bgp neighbors 10.1.0.1 received-routes` — what is the neighbor sending?

**No ECMP (`show ip route` shows only 1 path)**
- Check `maximum-paths 2 ecmp 2` is configured
- Check `bgp bestpath as-path multipath-relax` is present
- `show bgp 10.0.0.2/32` — how many paths are in the BGP RIB?

---

## Cleanup

```bash
sudo containerlab destroy -t labs/spine-leaf/topology.clab.yml --cleanup
```
