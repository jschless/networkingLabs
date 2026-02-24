# Lab: bfd-ospf

## Purpose
Learn BFD (Bidirectional Forwarding Detection) integrated with OSPF. See how BFD enables
sub-second failure detection — dramatically faster than OSPF's default 40-second dead timer.

## Topology

```
[r1] ---10.1.12.0/30--- [r2]
  \                       /
  10.1.13.0/30      10.1.23.0/30
    \                 /
         [r3]
```

| Link              | Subnet        | Addresses       |
|-------------------|---------------|-----------------|
| r1:eth1 - r2:eth1 | 10.1.12.0/30  | r1:.1  r2:.2    |
| r2:eth2 - r3:eth1 | 10.1.23.0/30  | r2:.1  r3:.2    |
| r1:eth2 - r3:eth2 | 10.1.13.0/30  | r1:.1  r3:.2    |

| Node | Loopback    |
|------|-------------|
| r1   | 10.0.0.1/32 |
| r2   | 10.0.0.2/32 |
| r3   | 10.0.0.3/32 |

All routers in OSPF area 0.

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## What You Configure

### Step 1: Configure OSPF on all nodes

Example for r1:

```
vtysh
configure terminal

interface lo
 ip ospf area 0

interface eth1
 ip ospf area 0

interface eth2
 ip ospf area 0

router ospf
 router-id 10.0.0.1

end
write memory
```

Repeat for r2 (router-id 10.0.0.2) and r3 (router-id 10.0.0.3).

Verify OSPF neighbors are up before enabling BFD:

```
show ip ospf neighbor
```

### Step 2: Enable BFD on OSPF interfaces

Add BFD to each interface on each router:

```
vtysh
configure terminal

interface eth1
 ip ospf bfd

interface eth2
 ip ospf bfd

end
write memory
```

### Step 3 (Optional): Tune BFD timers

Default BFD timers are 300ms tx/rx with multiplier 3 (failure = 900ms).
You can tune them:

```
interface eth1
 ip ospf bfd detect-multiplier 3
 ip ospf bfd min-rx 300
 ip ospf bfd min-tx 300
```

Faster (more aggressive, more CPU):

```
interface eth1
 ip ospf bfd detect-multiplier 3
 ip ospf bfd min-rx 100
 ip ospf bfd min-tx 100
```

### Step 4: Verify BFD sessions

```
show bfd peers
show bfd peers detail
show ip ospf neighbor
```

You should see BFD sessions in UP state for each OSPF neighbor.

### Step 5: Simulate a link failure

Open two terminal windows. In one, watch OSPF:

```bash
docker exec -it clab-bfd-ospf-r1 vtysh -c "show ip ospf neighbor"
# Run repeatedly with watch:
watch -n0.5 'docker exec clab-bfd-ospf-r1 vtysh -c "show ip ospf neighbor"'
```

In the other, bring down a link:

```bash
docker exec clab-bfd-ospf-r2 ip link set eth1 down
```

With BFD enabled, OSPF should reconverge in under 1 second.
Without BFD, OSPF would wait 40 seconds (dead interval) before declaring the neighbor down.

Bring the link back up:

```bash
docker exec clab-bfd-ospf-r2 ip link set eth1 up
```

## Verification Commands

```
# BFD
show bfd peers                    # all BFD sessions and state
show bfd peers detail             # timers, counters, interface
show bfd peer 10.1.12.1           # specific peer

# OSPF
show ip ospf neighbor             # OSPF neighbors + BFD state
show ip ospf neighbor detail      # full neighbor state
show ip route ospf                # OSPF-learned routes
show ip ospf interface eth1       # interface-level OSPF state
```

## Concepts

### Why BFD?

OSPF's failure detection relies on Hello/Dead timers:
- Hello interval: 10 seconds (default)
- Dead interval: 40 seconds (default, = 4 × hello)

That means a link failure won't be detected for up to **40 seconds**, during which
traffic is blackholed.

BFD solves this:
- BFD sends lightweight hello packets at very short intervals (as low as 50ms)
- BFD failure detection: `detect-multiplier × min-rx` = 3 × 300ms = **900ms** by default
- With aggressive timers (3 × 100ms): failure detection in **300ms**

### BFD Architecture

```
+---Router A---+                +---Router B---+
| OSPF         |                | OSPF         |
| (registers   |                | (registers   |
|  neighbor)   |                |  neighbor)   |
|      |       |                |      |       |
|   BFD daemon |<-BFD hellos -> | BFD daemon   |
|      |       |                |      |       |
| zebra/kernel |                | zebra/kernel |
+------+-------+                +------+-------+
       |                               |
       +------- physical link ---------+
```

BFD is independent of OSPF — it operates at the forwarding plane level. When BFD
declares a peer down, it notifies all registered protocols (OSPF, BGP, IS-IS) immediately.

### BFD Modes

**Asynchronous mode** (default): Both sides send BFD control packets periodically.
Failure detected when N consecutive packets are missed.

**Demand mode**: Packets only sent when explicitly requested. Less common.

**Echo mode**: Packets are looped back by the remote side without processing.
Useful for testing the forwarding path specifically.

### BFD Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| min-tx | Minimum transmit interval (ms) | 300ms |
| min-rx | Minimum receive interval (ms) | 300ms |
| detect-multiplier | Failure threshold (multiples of min-rx) | 3 |

Failure detection time = `detect-multiplier × max(local min-rx, remote min-tx)`

### show bfd peers Output Explained

```
BFD Peers:
    peer 10.1.12.2 local-address 10.1.12.1 vrf default interface eth1
        ID: 1234567890
        Remote ID: 987654321
        Active mode
        Status: up                  <-- session is healthy
        Uptime: 5 minute(s), 3 second(s)
        Diagnostics: ok
        Remote diagnostics: ok
        Peer Type: dynamic
        RTT min/avg/max: 0/0/0 usec
        Local timers:
                Detect-multiplier: 3
                Receive interval: 300ms    <-- our negotiated rx interval
                Transmission interval: 300ms
                Echo receive interval: 50ms
                Echo transmission interval: disabled
        Remote timers:
                Detect-multiplier: 3
                Receive interval: 300ms
                Transmission interval: 300ms
                Echo receive interval: 50ms
```

## Challenge Exercises

1. Before enabling BFD, time how long it takes OSPF to detect a downed link
   by running `watch` on `show ip ospf neighbor` and then doing `ip link set eth1 down`.
   Record the convergence time.

2. Enable BFD and repeat the test. Compare convergence times.

3. Try setting very aggressive BFD timers (50ms × 3). Do BFD sessions stay stable
   in a virtual environment? What happens if the host is under load?

4. Check `show bfd peers detail` for packet counters. What do `TX` and `RX` counts
   tell you about the BFD health?

5. Configure BFD on the loopback as well (for completeness). Does it form a session?
   Why or why not?
