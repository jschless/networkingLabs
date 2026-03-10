# Lab: OSPF NSSA (Not-So-Stubby Area)

## Topology

```
[ext] --192.168.100.0/30-- [r1 ASBR] --area1(NSSA)-- [r2 ABR] --area0-- [r3]
192.168.100.2                  .1                       .2/.1                .2
                           10.0.0.1                  10.0.0.2            10.0.0.3
```

| Link | Subnet | Left | Right | OSPF Area |
|------|--------|------|-------|-----------|
| ext:Ethernet1 - r1:Ethernet1 | 192.168.100.0/30 | ext=.2 | r1=.1 | none (external) |
| r1:Ethernet2 - r2:Ethernet1  | 10.1.12.0/30    | r1=.1  | r2=.2 | Area 1 (NSSA) |
| r2:Ethernet2 - r3:Ethernet1  | 10.1.23.0/30    | r2=.1  | r3=.2 | Area 0 |

Loopbacks: r1=10.0.0.1/32 (area1), r2=10.0.0.2/32 (area0), r3=10.0.0.3/32 (area0)

## Concepts

### OSPF Area Types Comparison

| Area Type | Type-3 (inter-area) | Type-5 (external) | Type-7 (NSSA ext) | ASBR inside? |
|-----------|--------------------|--------------------|-------------------|--------------|
| Regular | Yes | Yes | No | Yes |
| Stub | Yes | No | No | No |
| Totally Stub | Default only | No | No | No |
| NSSA | Yes | No | Yes | **Yes** |
| Totally NSSA | Default only | No | Yes | Yes |

The key insight: **NSSA allows an ASBR inside a stub-like area**. This is
the "Not So Stubby" part — it's almost a stub (blocks Type-5), but not
completely (allows Type-7 for internal redistribution).

### Type-7 LSA (NSSA External)

When an ASBR inside an NSSA redistributes an external route, it generates
a **Type-7 LSA** instead of Type-5:

- Type-7 LSAs are **only flooded within the NSSA** (not to other areas)
- The Type-7 LSA contains a **Forward Address** — the actual next-hop IP
  that other routers should use to reach the external destination
- Type-7 LSAs have the **P-bit** (Propagate bit) set if the ABR should
  translate them to Type-5

### Type-7 to Type-5 Translation

The ABR (r2) automatically translates Type-7 → Type-5 when:
1. The area is configured as NSSA on the ABR
2. The ABR has the highest router-id in the NSSA (in multi-ABR scenarios)
3. The P-bit is set in the Type-7 LSA

After translation:
- r3 (area 0) sees a **Type-5 LSA** originated by r2 (not r1)
- The route appears as **O E2** in the routing table
- r3 has no knowledge that Type-7 existed — it looks like normal redistribution

### `area X nssa no-summary` (Totally NSSA)

```
router ospf
 area 1 nssa no-summary
```

This adds the "totally" modifier: the ABR stops sending Type-3 (inter-area
summary) LSAs into area 1. Area 1 routers only receive:
- Intra-area routes (Type-1, Type-2)
- A default route (Type-3 default 0.0.0.0/0 from the ABR)
- Type-7 LSAs from local ASBRs

This minimises the LSA database in the NSSA and forces all external traffic
through the ABR's default route.

## Deployment

```bash
sudo containerlab deploy -t topology.yml
```

## Tasks

### Step 1: Configure basic OSPF (without NSSA first)

On r1:
```
router ospf
 router-id 10.0.0.1
 network 10.0.0.1/32 area 1
 network 10.1.12.0/30 area 1
```

On r2:
```
router ospf
 router-id 10.0.0.2
 network 10.0.0.2/32 area 0
 network 10.1.12.0/30 area 1
 network 10.1.23.0/30 area 0
```

On r3:
```
router ospf
 router-id 10.0.0.3
 network 10.0.0.3/32 area 0
 network 10.1.23.0/30 area 0
```

Verify neighbors:
```
show ip ospf neighbor
```

### Step 2: Attempt redistribution WITHOUT NSSA

On r1, try to redistribute connected:
```
router ospf
 redistribute connected
```

Check the database on r3:
```
show ip ospf database external
```

If area 1 is a regular area, you'll see Type-5 LSAs. If it were configured
as a stub area, redistribution would be blocked entirely. NSSA is the
middle ground.

### Step 3: Configure area 1 as NSSA

On r1:
```
router ospf
 area 1 nssa
```

On r2:
```
router ospf
 area 1 nssa
```

Both routers in area 1 must agree on the area type.

### Step 4: Verify Type-7 LSA on r1

```
show ip ospf database nssa-external
```

Expected output:
```
OSPF Router with ID (10.0.0.1) (Process ID 0)

        NSSA-external Link States (Area 1)

 LS age: 42
Options: (No TOS-capability, DC, Upward)
 LS Type: AS NSSA-external Link State
Link State ID: 192.168.100.0 (External Network Number For This Type)
Advertising Router: 10.0.0.1
...
Forward Address: 192.168.100.1
```

The **Forward Address** is r1's address on the external segment. Area 0
routers use this as the next-hop for the external prefix.

### Step 5: Verify Type-5 LSA on r3 (ABR translation)

```
show ip ospf database external
```

Expected: Type-5 for 192.168.100.0/30, **Advertising Router: 10.0.0.2** (r2).
Note that r2 is the advertising router even though r1 originated the route.

```
show ip route ospf
```

Expected:
```
O E2   192.168.100.0/30 [110/20] via 10.1.23.1, Ethernet1
```

### Step 6: Test end-to-end reachability

```
ping 192.168.100.2 source 10.0.0.3
```

ext has a static default route toward r1, so it can return the pings.

### Step 7 (Optional): Try totally NSSA

On r2 only (the ABR):
```
router ospf
 area 1 nssa no-summary
```

On r1, check the routing table — the inter-area routes (O IA) to r3's
loopback should disappear and be replaced by a single default route:
```
show ip route ospf
```

Expected: `O N2 0.0.0.0/0` (default from ABR) instead of specific Type-3 routes.

## OSPF Database Commands

| Command | What it shows |
|---------|--------------|
| `show ip ospf database` | Summary of all LSA types |
| `show ip ospf database router` | Type-1 (Router LSAs) |
| `show ip ospf database network` | Type-2 (Network LSAs) |
| `show ip ospf database summary` | Type-3 (Inter-area summary LSAs) |
| `show ip ospf database external` | Type-5 (AS External LSAs) |
| `show ip ospf database nssa-external` | Type-7 (NSSA External LSAs) |
| `show ip ospf database external detail` | Full Type-5 detail with forward addr |

## Verification Summary

| Command | Where | Expected result |
|---------|-------|----------------|
| `show ip ospf neighbor` | r2 | r1 (area 1) and r3 (area 0) |
| `show ip ospf database nssa-external` | r1, r2 | Type-7 from r1 (10.0.0.1) |
| `show ip ospf database external` | r3 | Type-5 from r2 (10.0.0.2) |
| `show ip route ospf` | r3 | O E2 192.168.100.0/30 |
| `ping 192.168.100.2 source 10.0.0.3` | r3 | Success |

## Teardown

```bash
sudo containerlab destroy -t topology.yml
```
