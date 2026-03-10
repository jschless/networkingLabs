# Lab: OSPF MD5 Authentication

## Overview

This lab teaches you how to configure and troubleshoot OSPF MD5 authentication.
Without authentication, any router that connects to a network segment can inject
false LSAs, potentially poisoning routing tables across the entire OSPF domain.
MD5 authentication ensures that only routers sharing the correct key can form
adjacencies and exchange LSAs.

## Topology

```
[r1] Ethernet1 --- Ethernet1 [r2] Ethernet2 --- Ethernet1 [r3]
```

| Segment       | Subnet        | r1/r2/r3 address |
|---------------|---------------|------------------|
| r1 -- r2      | 10.1.12.0/30  | r1=.1, r2=.2     |
| r2 -- r3      | 10.1.23.0/30  | r2=.1, r3=.2     |
| r1 loopback   | 10.0.0.1/32   |                  |
| r2 loopback   | 10.0.0.2/32   |                  |
| r3 loopback   | 10.0.0.3/32   |                  |

All interfaces are in OSPF area 0.

## Lab Setup

```bash
sudo containerlab deploy -t topology.yml
```

Connect to a router:
```bash
sudo docker exec -it clab-ospf-auth-r1 Cli
```

## Step 1 — Basic OSPF (No Authentication)

Get OSPF adjacencies working first. Configure all three routers with basic OSPF
before adding authentication. This confirms the base topology is working.

On **r1**:
```
configure terminal
router ospf
 ospf router-id 10.0.0.1
 network 10.0.0.1/32 area 0
 network 10.1.12.0/30 area 0
 passive-interface Loopback0
```

On **r2**:
```
configure terminal
router ospf
 ospf router-id 10.0.0.2
 network 10.0.0.2/32 area 0
 network 10.1.12.0/30 area 0
 network 10.1.23.0/30 area 0
 passive-interface Loopback0
```

On **r3**:
```
configure terminal
router ospf
 ospf router-id 10.0.0.3
 network 10.0.0.3/32 area 0
 network 10.1.23.0/30 area 0
 passive-interface Loopback0
```

Verify adjacencies are up:
```
show ip ospf neighbor
```

Expected output — all neighbors in `Full` state:

```
r2# show ip ospf neighbor

Neighbor ID Instance VRF      Pri State                  Dead Time   Address         Interface
10.0.0.1         1 default     1 Full/DR                  00:00:39   10.1.12.1       Ethernet1
10.0.0.3         1 default     1 Full/BDR                 00:00:37   10.1.23.2       Ethernet2
```

Verify end-to-end reachability:
```
r1# ping 10.0.0.3 source 10.0.0.1
```

## Step 2 — Add MD5 Authentication

Now add MD5 authentication to every OSPF interface. The key **must match on both
ends** of each link — a mismatch prevents adjacency formation.

The authentication key is **per-interface** and identified by a numeric key ID.
Multiple keys can coexist on an interface (used for key rollover).

On **r1** (Ethernet1 only):
```
configure terminal
interface Ethernet1
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 SecretKey123
```

On **r2** (both Ethernet1 and Ethernet2):
```
configure terminal
interface Ethernet1
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 SecretKey123
interface Ethernet2
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 SecretKey123
```

On **r3** (Ethernet1 only):
```
configure terminal
interface Ethernet1
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 SecretKey123
```

Verify authentication is configured on an interface:
```
r2# show ip ospf interface Ethernet1
```

Look for the line `Internet Address ... Area ... MTU ...` followed by:
```
  Authentication MD5
  Cryptographic sequence number 0
  Key ID: 1, Auth data length: 16, Auth data: 0x...
```

Verify adjacencies are still `Full` after adding auth:
```
show ip ospf neighbor
```

## Step 3 — Experiment: Deliberate Key Mismatch

This simulates a misconfiguration or a rogue router. Change the key on **r1 only**:

```
r1# configure terminal
r1(config)# interface Ethernet1
r1(config-if)# ip ospf message-digest-key 1 md5 WrongKeyHere
```

Wait about 40 seconds (the default dead interval). Observe on **r2**:
```
r2# show ip ospf neighbor
```

The neighbor `10.0.0.1` will disappear from the table.

Notice that r3 is **unaffected** — the mismatch is localized to the r1-r2 link.

## Step 4 — Fix the Mismatch

Restore the correct key on r1:
```
r1# configure terminal
r1(config)# interface Ethernet1
r1(config-if)# ip ospf message-digest-key 1 md5 SecretKey123
```

The adjacency will recover within the hello interval (10 seconds default). Watch
it come back:
```
r2# show ip ospf neighbor
```

## Per-Interface Auth vs. Area Auth

There are two ways to enable OSPF authentication:

**Per-interface** (what we did above — more flexible):
```
interface Ethernet1
 ip ospf authentication message-digest
 ip ospf message-digest-key 1 md5 MyKey
```

**Area-wide** (set auth type once, still configure key per-interface):
```
router ospf
 area 0 authentication message-digest

interface Ethernet1
 ip ospf message-digest-key 1 md5 MyKey
```

Area-wide auth is easier to manage in large deployments but the key must still
be configured on every interface. Per-interface auth overrides area auth if both
are present.

## Key Rollover Procedure (Zero-Downtime)

In production, changing authentication keys without dropping adjacencies requires
a two-step rollover. OSPF supports multiple simultaneous keys per interface for
exactly this purpose.

**Step 1 — Add the new key (key ID 2) on ALL routers simultaneously:**
```
interface Ethernet1
 ip ospf message-digest-key 2 md5 NewSecretKey456
```

Both key 1 and key 2 are now active. cEOS will accept packets signed with either
key and will use the highest key ID to sign outgoing packets. Adjacencies remain
up throughout.

**Step 2 — Remove the old key (key ID 1) on ALL routers:**
```
interface Ethernet1
 no ip ospf message-digest-key 1 md5 SecretKey123
```

Only key 2 remains. The rollover is complete with no adjacency disruption.

**Important:** Add the new key everywhere before removing the old key anywhere.
If you remove the old key on one side before the other side has the new key, the
adjacency will drop.

## Troubleshooting Reference

| Command | What to look for |
|---------|-----------------|
| `show ip ospf neighbor` | Neighbor state (`Full` = healthy) |
| `show ip ospf interface Ethernet1` | Auth type, active key IDs |
| `show ip ospf database` | LSA count — should be consistent across all routers |
| `show ip route ospf` | OSPF-learned routes with `O` prefix |
| `debug ospf packet all` | Live packet events (verbose — disable after use) |

To disable debug:
```
no debug ospf packet all
```

## SHA Authentication (cEOS Extension)

cEOS also supports HMAC-SHA authentication as an extension beyond the standard:
```
interface Ethernet1
 ip ospf authentication hmac-sha-256
 ip ospf authentication-key MySharedKey
```

SHA-256 provides stronger cryptographic guarantees than MD5. However, this is
**not interoperable** with vendors that only implement RFC 5709 HMAC-SHA or with
older Cisco IOS. Use MD5 when interoperability is required.

## Cleanup

```bash
sudo containerlab destroy -t topology.yml
```
