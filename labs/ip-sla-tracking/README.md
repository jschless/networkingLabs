# Lab: IP SLA + Object Tracking + Floating Static Routes

## Overview

This lab teaches IP SLA probes combined with object tracking and floating static
routes to achieve automatic failover. When the primary ISP link goes down, a
tracked static route is withdrawn from the routing table and the backup static
route (with higher administrative distance) takes its place automatically.

## Topology

```
[router] --eth1--> [isp1]  10.0.1.0/30   (primary, AD=5)
         --eth2--> [isp2]  10.0.2.0/30   (backup,  AD=10)

Both ISPs loopback: 10.99.0.1/32 (simulated internet)
```

## IP Addressing

| Node   | Interface | Address       | Notes                        |
|--------|-----------|---------------|------------------------------|
| router | eth1      | 10.0.1.1/30   | primary uplink               |
| isp1   | eth1      | 10.0.1.2/30   |                              |
| isp1   | lo        | 10.99.0.1/32  | SLA probe target             |
| router | eth2      | 10.0.2.1/30   | backup uplink                |
| isp2   | eth1      | 10.0.2.2/30   |                              |
| isp2   | lo        | 10.99.0.1/32  | same IP — both ISPs reachable|

## Lab Steps

### Step 1: Start the lab

```bash
sudo containerlab deploy -t topology.clab.yml
```

Verify both ISPs are reachable:
```
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- Cli -c "ping 10.0.1.2"
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- Cli -c "ping 10.0.2.2"
```

### Step 2: Configure floating static routes (no tracking yet)

On **router**:
```
Cli
conf t
ip route 0.0.0.0/0 10.0.1.2 5
ip route 0.0.0.0/0 10.0.2.2 10
```

Check routing table:
```
show ip route
```

Only one route will appear: `S>* 0.0.0.0/0 [5/0] via 10.0.1.2` (AD=5 wins).
The backup at AD=10 exists but is not installed in the RIB (lower priority).

Verify both routes are configured:
```
show ip route 0.0.0.0/0 longer-prefixes
```

### Step 3: Configure IP SLA probe

On **router**:
```
Cli
conf t
ip sla 1
 icmp-echo 10.99.0.1 source-interface eth1
 frequency 5
ip sla schedule 1 life forever start-time now
```

Check SLA status:
```
show ip sla statistics
```

You should see `Latest operation return code: Success` and the round-trip time
for ICMP echo probes to 10.99.0.1 via eth1.

### Step 4: Configure track object

On **router**:
```
Cli
conf t
track 1 ip sla 1 reachability
```

Check track status:
```
show track 1
```

Output will show `State is Up` when the SLA probe succeeds.

### Step 5: Tie primary route to track object

On **router** — remove the untracked primary route and replace with tracked version:
```
Cli
conf t
no ip route 0.0.0.0/0 10.0.1.2 5
ip route 0.0.0.0/0 10.0.1.2 5 track 1
```

Verify routing table still shows primary as active:
```
show ip route
```

### Step 6: Simulate isp1 failure

On the **router** node, bring down eth1:
```
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- ip link set eth1 down
```

Wait a few seconds (SLA frequency is 5 seconds), then check:

```
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- Cli -c "show track 1"
```

Track state changes to `Down`. Then check routing table:

```
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- Cli -c "show ip route"
```

The primary route (AD=5) should be gone. The backup (AD=10) should now be
installed: `S>* 0.0.0.0/0 [10/0] via 10.0.2.2`.

Test connectivity via backup path:
```
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- ping 10.0.2.2
```

### Step 7: Restore isp1 and verify recovery

```
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- ip link set eth1 up
```

Wait for the SLA probe to succeed (up to 5 seconds), then:
```
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- Cli -c "show track 1"
sudo containerlab exec -t topology.clab.yml --label clab-node-name=router -- Cli -c "show ip route"
```

Primary route reinstalls and backup returns to standby state.

## Key Concepts

### IP SLA probe types

| Type         | Command                           | Use case                    |
|--------------|-----------------------------------|-----------------------------|
| icmp-echo    | `icmp-echo <target>`              | Reachability probe (ping)   |
| tcp-connect  | `tcp-connect <target> <port>`     | Service availability check  |
| udp-echo     | `udp-echo <target> <port>`        | UDP service check           |

In cEOS, only `icmp-echo` is fully supported in current versions.

### Track object states

```
track 1 ip sla 1 reachability
```

- `Up`: the SLA probe is succeeding (return code = Success)
- `Down`: the SLA probe is failing (timeout, unreachable, etc.)

The track object translates SLA results into binary Up/Down for use by routes.

### Floating static route

A floating static route has a higher administrative distance than the primary.
It stays in the configuration but is only installed in the RIB when all
lower-AD paths to the same prefix are absent.

```
ip route 0.0.0.0/0 10.0.1.2 5    ! Primary: AD=5 (installed when track up)
ip route 0.0.0.0/0 10.0.2.2 10   ! Backup:  AD=10 (installed when primary withdrawn)
```

### Track + static route interaction

Adding `track 1` to a static route means:
- When track 1 = Up: route is eligible for installation (subject to AD)
- When track 1 = Down: route is immediately withdrawn from the RIB

This is different from the route simply failing (e.g., next-hop unreachable). The
track check is proactive — the SLA probe detects failure independently of the
routing table.

### SLA timing

The `frequency` parameter sets the probe interval in seconds. The `ip sla schedule`
command activates the probe. By default, a single probe failure does NOT
immediately flip the track to Down — cEOS uses configurable thresholds.

To check:
```
show ip sla configuration 1
show ip sla statistics 1
show track
```

## Teardown

```bash
sudo containerlab destroy -t topology.clab.yml
```
