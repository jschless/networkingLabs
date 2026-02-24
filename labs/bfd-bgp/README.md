# Lab: bfd-bgp

## Purpose
Learn BFD (Bidirectional Forwarding Detection) integrated with BGP. Understand how BFD
enables near-instant BGP session teardown on link failure, replacing the slow 90-second
hold timer mechanism.

## Topology

```
[r1 AS65001] ---10.1.12.0/30--- [r2 AS65002] ---10.1.23.0/30--- [r3 AS65003]
```

| Link              | Subnet        | Addresses       | BGP Session          |
|-------------------|---------------|-----------------|----------------------|
| r1:eth1 - r2:eth1 | 10.1.12.0/30  | r1:.1  r2:.2    | eBGP 65001 <-> 65002 |
| r2:eth2 - r3:eth1 | 10.1.23.0/30  | r2:.1  r3:.2    | eBGP 65002 <-> 65003 |

| Node | Loopback    | AS    |
|------|-------------|-------|
| r1   | 10.0.0.1/32 | 65001 |
| r2   | 10.0.0.2/32 | 65002 |
| r3   | 10.0.0.3/32 | 65003 |

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## What You Configure

### Step 1: Configure BGP on all nodes (without BFD first)

Example for r1:

```
vtysh
configure terminal

router bgp 65001
 bgp router-id 10.0.0.1
 no bgp ebgp-requires-policy
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 description r2
 address-family ipv4 unicast
  network 10.0.0.1/32
 exit-address-family

end
write memory
```

For r2 (two neighbors):

```
router bgp 65002
 bgp router-id 10.0.0.2
 no bgp ebgp-requires-policy
 neighbor 10.1.12.1 remote-as 65001
 neighbor 10.1.12.1 description r1
 neighbor 10.1.23.2 remote-as 65003
 neighbor 10.1.23.2 description r3
 address-family ipv4 unicast
  network 10.0.0.2/32
 exit-address-family
```

For r3:

```
router bgp 65003
 bgp router-id 10.0.0.3
 no bgp ebgp-requires-policy
 neighbor 10.1.23.1 remote-as 65002
 neighbor 10.1.23.1 description r2
 address-family ipv4 unicast
  network 10.0.0.3/32
 exit-address-family
```

Verify BGP sessions are Established:

```
show bgp ipv4 unicast summary
```

### Step 2: Time BGP convergence WITHOUT BFD

Open a watch window on r1:

```bash
watch -n0.5 'docker exec clab-bfd-bgp-r1 vtysh -c "show bgp ipv4 unicast summary"'
```

Kill the link between r1 and r2:

```bash
docker exec clab-bfd-bgp-r2 ip link set eth1 down
```

Observe: BGP session stays in Established state until the hold timer expires (90 seconds).
Record how long it takes.

Restore the link:

```bash
docker exec clab-bfd-bgp-r2 ip link set eth1 up
```

### Step 3: Enable BFD per BGP neighbor

```
vtysh
configure terminal

router bgp 65001
 neighbor 10.1.12.2 bfd

end
write memory
```

Do this on all routers for all neighbors. On r2:

```
router bgp 65002
 neighbor 10.1.12.1 bfd
 neighbor 10.1.23.2 bfd
```

### Step 4: Verify BFD sessions

```
show bfd peers
show bfd peers detail
show bgp ipv4 unicast summary
```

Each BGP neighbor should have a corresponding BFD session in UP state.

### Step 5: Time BGP convergence WITH BFD

Repeat the link-down test. BGP session should tear down in under 1 second.

```bash
# Watch BGP summary
watch -n0.5 'docker exec clab-bfd-bgp-r1 vtysh -c "show bgp ipv4 unicast summary"'

# Kill the link
docker exec clab-bfd-bgp-r2 ip link set eth1 down
```

## Verification Commands

```
# BFD
show bfd peers                        # all sessions, state, interface
show bfd peers detail                 # full timer and counter detail
show bfd peer 10.1.12.2               # specific peer

# BGP
show bgp ipv4 unicast summary         # session state, prefixes
show bgp ipv4 unicast neighbors 10.1.12.2   # neighbor detail including BFD
show ip route bgp                     # BGP-installed routes
```

## Concepts

### BGP Hold Timer vs BFD

**Without BFD:**

```
BGP keepalive: every 30 seconds (default: holdtime/3)
BGP hold timer: 90 seconds (default)

Failure detection: up to 90 seconds after last keepalive
  (three missed keepalives, but hold timer starts from last received)
```

**With BFD:**

```
BFD default timers: 300ms tx/rx, multiplier 3
Failure detection: 3 × 300ms = 900ms

Traffic blackhole window: <1 second vs up to 90 seconds
```

### BFD in BGP — How It Works

1. BGP session comes up between two neighbors
2. BGP informs BFD: "please monitor 10.1.12.2 for me"
3. BFD establishes a separate control-plane session with 10.1.12.2
4. BFD sends/receives lightweight packets at the negotiated interval
5. If BFD detects failure (N consecutive packets lost):
   - BFD notifies BGP immediately
   - BGP tears down the session without waiting for hold timer
   - BGP withdraws routes from the failed session
   - Routing reconverges

### BFD Per-Neighbor Configuration

BFD in BGP is configured per-neighbor (not per-interface):

```
router bgp 65001
 neighbor 10.1.12.2 bfd                           # enable BFD
 neighbor 10.1.12.2 bfd check-control-plane-failure  # optional: also check CP
```

You can also set custom timers per-neighbor:

```
router bgp 65001
 neighbor 10.1.12.2 bfd profile FAST_BFD

bfd
 profile FAST_BFD
  transmit-interval 100
  receive-interval 100
  detect-multiplier 3
```

### BFD vs BGP Hold Timer — When Each Applies

| Scenario | BFD Detects? | Hold Timer Applies? |
|----------|--------------|---------------------|
| Physical link failure | Yes — immediately | No (BFD wins) |
| Software crash on remote router | Maybe — if BFD process dies too | Yes |
| Remote BFD daemon crash | No — BFD session drops, hold timer takes over | Yes |
| BGP process crash (keepalives stop) | No — BFD still UP | Yes |

BFD detects **forwarding plane** failures. Hold timer detects **control plane** failures.
They are complementary, not mutually exclusive.

### FRR Note: no bgp ebgp-requires-policy

FRR 8.x requires explicit policy (route-maps) on eBGP sessions by default.
Adding `no bgp ebgp-requires-policy` disables this requirement for the lab,
allowing routes to be accepted and advertised without explicit route-maps.

## Challenge Exercises

1. Measure convergence time precisely using `date` before and after bringing the link down.
   What is the actual convergence time with BFD enabled?

2. Configure custom BFD timers with 100ms intervals. Does this further reduce convergence?
   How stable are the BFD sessions at 100ms in a virtual environment?

3. What happens if you configure BFD on r1 but NOT on r2 for the same session?
   Does BFD still work? (Hint: check `show bfd peers` on r2.)

4. Try adding a BFD profile with `bfd` stanza and custom timers, then apply it to
   the BGP neighbor with `neighbor X.X.X.X bfd profile PROFILENAME`.

5. Observe what happens to BFD when you do `docker pause clab-bfd-bgp-r2` (pauses
   the container — simulates a frozen/busy router). Does BFD or hold timer trigger first?
