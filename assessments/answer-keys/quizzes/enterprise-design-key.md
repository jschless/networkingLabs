# Enterprise Campus Design Quiz — Answer Key

**Total:** 30 points

## A. Design Models (6 points)

### A1. Campus design comparison (3 points)

Award 1 point for each accurate comparison:

- **Collapsed core:** Access switches commonly extend Layer 2 to a combined distribution/core pair. SVIs and first-hop redundancy live on that pair, which is simple for smaller campuses but concentrates gateway, Layer 2, and core functions in one failure domain.
- **Three-tier campus:** Access switches extend Layer 2 to a distribution block, where SVIs, first-hop redundancy, and policy are normally placed. A routed core interconnects distribution blocks and limits the blast radius of individual access/distribution failures.
- **Routed access:** Layer 2 domains and default gateways terminate at the access layer. Routed uplinks, an IGP, and often ECMP/BFD replace spanning-tree-dependent uplink recovery, reducing Layer 2 failure domains at the cost of a different mobility and operational model.

### A2. STP and first-hop redundancy alignment (3 points)

- 1 point: The spanning-tree root and VRRP master should normally be on the same distribution switch for a VLAN.
- 1 point: Alignment lets access traffic follow the active Layer 2 path directly to its active default gateway.
- 1 point: With a mismatch, traffic can travel to the STP root, cross the inter-distribution link to the VRRP master, and then continue northbound. This adds latency, consumes peer-link capacity, and makes that link part of the forwarding path.

## B. Failure Localization (8 points)

### B1. Single-homed access switch (8 points)

- 2 points: Correctly localizes the fault to the physical/Layer 2 access topology. Healthy OSPF and VRRP on the distribution pair cannot preserve service when `acc1` has no surviving uplink.
- 2 points: Identifies the minimum topology repair: add a second trunk from `acc1` to `dist2`.
- 1 point: Explains that spanning tree should leave one access uplink forwarding and the other blocked or alternate during steady state, assuming a traditional Layer 2 design.
- 1 point: Verifies trunk status, allowed VLANs, and STP port roles/states before and after a failure.
- 1 point: Verifies the VRRP master, virtual IP reachability, and host ARP/neighbor resolution.
- 1 point: Performs an end-host test through the default gateway and northbound path while each distribution/uplink failure is induced separately.

Do not award full credit for proposing only an OSPF or VRRP timer change; neither creates a missing physical path.

## C. Architecture Selection (10 points)

### C1. Select the campus model (10 points)

Award credit for a defensible choice tied to the stated requirements:

- **Small campus — collapsed core (3 points):** Low device count and modest scale make the simpler two-layer design reasonable. The answer should acknowledge the larger shared failure domain or the need for a redundant collapsed pair.
- **Large multi-building campus — three-tier (3 points):** Distribution blocks provide policy and fault containment per building or area, while the routed core supplies scalable, predictable inter-block transport.
- **Campus prioritizing small Layer 2 domains and fast routed convergence — routed access (4 points):** Gateways at the access layer and routed uplinks remove spanning tree from northbound recovery and constrain VLAN failures. Full credit requires noting a tradeoff such as operational complexity, address design, or reduced Layer 2 mobility.

Equivalent selections may receive credit when their assumptions and tradeoffs are explicit and technically sound.

## D. WAN Default-Route Safety (6 points)

### D1. Conditional default origination (6 points)

- 2 points: Explains that `default-information originate always` advertises an OSPF default even when the WAN edge has no usable Internet/BGP exit, attracting traffic into a black hole.
- 2 points: Proposes a conditional design, such as originating the default only while a real default exists in the RIB, or using a route map tied to a tracked next hop or validated upstream route.
- 1 point: Verifies the BGP session/upstream route, local RIB/FIB, and presence or withdrawal of the OSPF external default.
- 1 point: Tests end-to-end, bidirectional application or probe traffic from a campus host during normal operation and after each ISP failure.

## Remediation

| Weak area | Review |
|---|---|
| Collapsed-core tradeoffs and FHRP/STP alignment | `labs/enterprise-collapsed-core/` |
| Three-tier hierarchy and failure domains | `labs/enterprise-campus/` |
| Routed access and routed-uplink convergence | `labs/enterprise-routed-access/` |
| WAN-edge default origination and upstream failure behavior | `labs/enterprise-wan-edge/` |
