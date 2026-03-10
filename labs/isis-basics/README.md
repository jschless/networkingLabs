# Lab: isis-basics

## Purpose
Learn IS-IS (Intermediate System to Intermediate System) fundamentals: NET address format,
area configuration, Level-1/Level-2 operation, DIS election, and LSP flooding.

## Topology

```
[r1] --- [r2] --- [r3] --- [r4]
         (linear, all Level-2, area 49.0001)
```

| Link          | Subnet          | r-near IP    | r-far IP     |
|---------------|-----------------|--------------|--------------|
| r1:eth1-r2:eth1 | 10.1.12.0/30  | r1: .1       | r2: .2       |
| r2:eth2-r3:eth1 | 10.1.23.0/30  | r2: .1       | r3: .2       |
| r3:eth2-r4:eth1 | 10.1.34.0/30  | r3: .1       | r4: .2       |

| Node | Loopback     | NET Address                      |
|------|--------------|----------------------------------|
| r1   | 10.0.0.1/32  | 49.0001.0100.0000.0001.00        |
| r2   | 10.0.0.2/32  | 49.0001.0100.0000.0002.00        |
| r3   | 10.0.0.3/32  | 49.0001.0100.0000.0003.00        |
| r4   | 10.0.0.4/32  | 49.0001.0100.0000.0004.00        |

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## What You Configure

On each router, configure IS-IS. Example for r1:

```
Cli

configure terminal

interface lo
 ip router isis CORE
 isis passive

interface eth1
 ip router isis CORE

router isis CORE
 net 49.0001.0100.0000.0001.00
 is-type level-2-only

end
write memory
```

Repeat for r2, r3, r4 — substituting the correct NET address (see table above).

For r2 and r3, also configure eth2 under IS-IS:

```
interface eth2
 ip router isis CORE
```

## Verification

```bash
# SSH into a node
sudo containerlab inspect -t topology.yml
docker exec -it clab-isis-basics-r1 Cli

# Check IS-IS neighbors (should see adjacent routers)
show isis neighbor

# Check the IS-IS link-state database (LSPs from all routers)
show isis database

# Check IS-IS computed routes
show isis route

# Check the Linux routing table (populated by zebra from IS-IS)
show ip route

# Ping across the topology
ping 10.0.0.4 source 10.0.0.1
```

## Concepts

### NET Address Format

A NET (Network Entity Title) uniquely identifies an IS-IS router:

```
49.0001.0100.0000.0001.00
|  |    |              |
|  |    System ID      SEL (always 00)
|  Area ID (variable length)
AFI (49 = private)
```

- **AFI 49**: Private address space (like RFC 1918), used in all lab/production IS-IS
- **Area ID**: `0001` here — groups routers into the same area
- **System ID**: 6 bytes, must be unique in the domain. Convention: derive from loopback IP.
  - 10.0.0.1 → pad to 010.000.000.001 → 0100.0000.0001
- **SEL**: Always `00` for a router (non-zero means a specific service)

### IS-IS Levels

| Level | Scope | Analogy |
|-------|-------|---------|
| Level-1 (L1) | Intra-area only | OSPF intra-area |
| Level-2 (L2) | Inter-area backbone | OSPF backbone (area 0) |
| Level-1/2 | Both | OSPF ABR |

In this lab all routers run Level-2 only — a single flat backbone, simplest IS-IS config.

### DIS (Designated IS)

On broadcast (LAN) segments, IS-IS elects a DIS (Designated Intermediate System):

- Highest interface priority wins; tiebreak: highest SNPA (MAC address)
- DIS generates a **pseudonode LSP** to represent the LAN
- **Key difference from OSPF DR**: IS-IS non-DIS routers still form full adjacencies with each
  other. OSPF non-DR routers only talk to DR/BDR. IS-IS is fully meshed on the LAN.
- Point-to-point links (like veth pairs in ContainerLab) do NOT elect a DIS

ContainerLab veth links are point-to-point, so you will not see DIS election here.
To practice DIS, you would need multiple routers on the same bridge/VLAN.

### LSP (Link State PDU)

IS-IS uses LSPs (Link State PDUs) — the IS-IS equivalent of OSPF LSAs:

- Each router originates one or more LSPs describing its links and reachable prefixes
- LSPs are flooded to all routers in the level (L1 floods within area, L2 floods the backbone)
- The LSDB (Link State Database) contains all LSPs → SPF runs on this to compute routes
- LSPs are identified by: SystemID.pseudonode-number (e.g., `0100.0000.0001.00-00`)

### IS-IS vs OSPF

| Feature | IS-IS | OSPF |
|---------|-------|------|
| Transport | Directly over L2 (not IP) | IP protocol 89 |
| PDU format | TLV-based | Fixed + optional fields |
| Area model | Area boundaries on links | Area boundaries on routers |
| Use case | Service provider backbones | Enterprise networks |
| IPv6 support | Single process (multi-topology) | Separate OSPFv3 process |
| Scalability | Slightly better for large cores | Slightly better documentation |

IS-IS runs directly over Layer 2 — it does NOT use IP as transport. This makes it
immune to IP misconfigurations and is one reason large SP networks prefer it.

### Useful Show Commands

```
show isis neighbor              # adjacency table
show isis neighbor detail       # timers, state, circuit type
show isis database              # LSDB — all LSPs
show isis database detail       # full TLV content of each LSP
show isis route                 # IS-IS computed routes (before RIB install)
show ip route isis              # routes installed in cEOS RIB
show isis interface             # per-interface IS-IS state
```

## Challenge Exercises

1. After IS-IS converges, verify all four loopbacks are reachable from r1:
   `ping 10.0.0.2`, `ping 10.0.0.3`, `ping 10.0.0.4`

2. Adjust IS-IS metric on r2:eth1 to 100 (`isis metric 100`) and observe how
   `show isis route` changes on r1.

3. Shut r2 (remove it from the lab, or shut its interfaces) and observe how long
   it takes IS-IS to reconverge on r1. Compare to `show isis neighbor` holddown timer.

4. Change one router from `level-2-only` to `level-1-2` and observe what happens
   to the adjacency (hint: level mismatch causes adjacency problems).
