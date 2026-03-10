# Lab: Policy-Based Routing (PBR)

## Overview

This lab teaches Policy-Based Routing (PBR) — making forwarding decisions based
on source IP, destination IP, or other packet attributes rather than the
destination prefix alone.

The scenario: a router connects two hosts and two ISPs. Without PBR, all traffic
uses the same default route (isp1). With PBR, host-a traffic is steered to isp1
and host-b traffic is steered to isp2 regardless of the routing table.

## Topology

```
[host-a]   [host-b]
    \         /
   [router]
    /         \
 [isp1]     [isp2]
```

## IP Addressing

| Node   | Interface | Address         | Notes                  |
|--------|-----------|-----------------|------------------------|
| host-a | eth1      | 192.168.1.1/30  | default gw 192.168.1.2 |
| router | eth1      | 192.168.1.2/30  | faces host-a           |
| host-b | eth1      | 192.168.2.1/30  | default gw 192.168.2.2 |
| router | eth2      | 192.168.2.2/30  | faces host-b           |
| router | eth3      | 10.0.1.1/30     | faces isp1             |
| isp1   | eth1      | 10.0.1.2/30     |                        |
| isp1   | lo        | 10.99.1.1/32    | internet target        |
| router | eth4      | 10.0.2.1/30     | faces isp2             |
| isp2   | eth1      | 10.0.2.2/30     |                        |
| isp2   | lo        | 10.99.2.1/32    | internet target        |

## Lab Steps

### Step 1: Start the lab

```bash
sudo containerlab deploy -t topology.yml
```

Verify connectivity to each ISP from router:
```
sudo containerlab exec -t topology.yml --label clab-node-name=router -- Cli -c "ping 10.0.1.2"
sudo containerlab exec -t topology.yml --label clab-node-name=router -- Cli -c "ping 10.0.2.2"
```

### Step 2: Add default static route (baseline routing)

On **router** — establishes a default route so traffic without a PBR match
can still reach the internet via isp1:

```
Cli
conf t
ip route 0.0.0.0/0 10.0.1.2
```

Verify:
```
show ip route
```
You should see `S>* 0.0.0.0/0 [1/0] via 10.0.1.2`.

Test: ping isp2's loopback from router (should work via isp1's return route):
```
ping 10.99.1.1
```

### Step 3: Verify without PBR (both hosts use isp1)

From **host-a**, traceroute to isp2's loopback:
```
Cli -c "traceroute 10.99.2.1 source 192.168.1.1"
```

From **host-b**, traceroute to isp2's loopback:
```
Cli -c "traceroute 10.99.2.1 source 192.168.2.1"
```

Both will show the same path via 10.0.1.1 (isp1). This is the problem PBR solves.

### Step 4: Configure PBR on router

```
Cli
conf t

! Match host-a source subnet
ip access-list extended HOST-A
 permit ip 192.168.1.0/30 any

! Match host-b source subnet
ip access-list extended HOST-B
 permit ip 192.168.2.0/30 any

! PBR map: host-a -> isp1
route-map PBR-ISP1 permit 10
 match ip address HOST-A
 set ip next-hop 10.0.1.2

! PBR map: host-b -> isp2
route-map PBR-ISP2 permit 10
 match ip address HOST-B
 set ip next-hop 10.0.2.2

! Apply inbound on the interfaces where traffic arrives
interface Ethernet1
 ip policy route-map PBR-ISP1

interface Ethernet2
 ip policy route-map PBR-ISP2
```

### Step 5: Verify PBR steering

From **host-a**:
```
Cli -c "traceroute 10.99.2.1 source 192.168.1.1"
```
First hop should be 10.0.1.1 (router's eth3) -> isp1. Even though we are
reaching isp2's address, traffic exits via isp1.

From **host-b**:
```
Cli -c "traceroute 10.99.1.1 source 192.168.2.1"
```
First hop should be 10.0.2.1 (router's eth4) -> isp2.

Check PBR route-map hit counters on router:
```
show ip policy
show route-map
```

### Step 6: Check routing table (unchanged)

On **router**:
```
show ip route
```

Note that the routing table still shows only the default route via isp1 (10.0.1.2).
PBR does NOT modify the routing table. It intercepts packets before the routing
table lookup and forces a different next-hop.

## Key Concepts

### PBR vs routing table

The routing table makes forwarding decisions based on destination IP only.
PBR can match on source IP, destination IP, protocol, port (with ACLs), ToS,
packet length, and more. PBR runs before the routing table lookup.

### Inbound application

PBR is always applied **inbound** on the interface where traffic enters.
In this lab:
- Traffic from host-a arrives on eth1 -> PBR applied on eth1
- Traffic from host-b arrives on eth2 -> PBR applied on eth2

If a packet does not match any PBR map entry, it falls through to normal
routing table lookup.

### set ip next-hop vs set interface

```
set ip next-hop 10.0.1.2      ! Forward to specific next-hop IP
set interface eth3             ! Forward out specific interface (use with care)
set ip next-hop verify         ! Only use next-hop if it is in the routing table
```

### ip local policy (router-originated traffic)

PBR on interfaces only affects transit traffic (traffic passing through).
To apply PBR to traffic originated by the router itself:

```
ip local policy route-map MY-MAP
```

This is useful for controlling which interface the router uses for its own
management traffic, BGP sessions, etc.

### Asymmetric routing consideration

In this lab, ISPs have return routes for both LAN subnets. In a real network,
asymmetric routing (forward path via isp1, return via isp2) can cause issues
with stateful firewalls and NAT. PBR policies often need to be paired with
matching policies on the return path.

## Verification Commands

```
show ip policy                    ! Which interfaces have PBR applied
show route-map [name]             ! Route-map details and hit counters
show ip access-list               ! ACL match counters
debug ip pbr                      ! Real-time PBR decisions (noisy)
```

## Teardown

```bash
sudo containerlab destroy -t topology.yml
```
