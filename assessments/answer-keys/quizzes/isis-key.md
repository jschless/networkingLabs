# Answer Key — IS-IS Topic Quiz

**Total:** 20 points

## A1 — Identity in the NET (2 points)

- Area address: `49.0007`; system ID: `0100.0000.0012`; NSEL: `00`. (1)
- The system ID must be unique in the routing domain. A duplicate makes two routers
  originate colliding LSP IDs, causing LSDB instability/corruption and unreliable
  reachability. (1)

Accept `49` as the AFI plus `0007` as the area portion if the candidate clearly treats
the combined area address correctly.

## A2 — Leaving a Level-1 area (2 points)

An L1/L2 router sets the attached bit in its Level-1 LSP. L1 routers use the closest
attached L1/L2 router as an exit and install a default toward it. Route leaking imports
selected Level-2 specifics into Level 1, enabling more precise reachability and exit
selection at the cost of a larger L1 LSDB.

- attached bit and L1/L2 exit/default behavior: 1
- leaked specifics and their purpose: 1

## B1 — Default versus detail (6 points)

1. r2 is L1/L2 and sets ATT in its L1 LSP. r1 interprets that as reachability to the
   Level-2 backbone and installs the default toward r2. No manually originated default
   is required. (2)
2. No. By default, remote Level-2 specifics are not flooded down into Level 1; L1 uses
   the attached-bit default. r2's L2 database proves the remote prefix exists at the
   backbone level. (1)
3. On r2, use `redistribute level-2 into level-1 route-map <MAP>` with a route-map or
   equivalent policy permitting only `10.44.44.44/32`. Both the leak and the policy
   constraint are required. (2)
4. Leaking many specifics enlarges every L1 router's LSDB and RIB, increases flooding and
   SPF work, and weakens the hierarchy's scaling benefit. Any one earns the point. (1)

## C1 — An L1/L2 boundary router (5 points)

```text
interface Loopback0
   ip router isis CORE
   isis passive

interface Ethernet1
   ip router isis CORE

interface Ethernet2
   ip router isis CORE

router isis CORE
   net 49.0001.0100.0000.0002.00
   is-type level-1-2
```

- correct process name and NET: 1.5
- Level-1-2 process type: 1
- all three interfaces enrolled in the same process: 1.5
- loopback passive: 1

Putting `isis passive` on a transit interface loses credit because it prevents the
adjacency the interface exists to form.

## D1 — Same link, different areas (5 points)

1. r7 is in area `0001` and r8 is in area `0002`. A Level-1 adjacency is intra-area, so
   Level-1 Hellos require matching area addresses; the peers reject each other. (2)
2. Level 2 forms the inter-area backbone. Level-2-capable routers are allowed to form an
   L2 adjacency across different area addresses. (1)
3. Correct r8's NET area portion to `0001` while preserving its unique system ID. Then
   verify the adjacency with `show isis neighbors` and verify that both routers' LSPs and
   remote prefixes appear in the Level-1 database/RIB. One adjacency check and one
   LSDB/route or end-to-end check are required. (2)

**Misconception:** changing the system IDs to match would create a second, more serious
fault. It is the area portion that must match; system IDs must remain unique.

## Remediation table

| Question | Objective | Labs |
|---|---|---|
| A1 | NET structure and system-ID uniqueness | `isis-basics` |
| A2, B1 | L1/L2 hierarchy, attached bit, route leaking | `isis-multiarea` |
| C1 | EOS process and interface configuration | `isis-basics`, `isis-multiarea` |
| D1 | Level-specific adjacency and area mismatch | `debug-isis-basics`, `isis-basics` |
