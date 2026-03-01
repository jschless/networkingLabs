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
sudo containerlab deploy -t labs/spine-leaf-ceos/topology.yml

# EOS CLI
docker exec -it clab-spine-leaf-ceos-spine1 Cli
docker exec -it clab-spine-leaf-ceos-leaf1  Cli
```

---

## Step 1 — Configure spine1 (AS65100)

```bash
docker exec -it clab-spine-leaf-ceos-spine1 Cli
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
docker exec -it clab-spine-leaf-ceos-spine2 Cli
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
docker exec -it clab-spine-leaf-ceos-leaf1 Cli
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
sudo containerlab destroy -t labs/spine-leaf-ceos/topology.yml --cleanup
```
