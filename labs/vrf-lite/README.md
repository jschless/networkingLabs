# VRF-Lite — Practice Lab

Configure VRF-Lite (Virtual Routing and Forwarding without MPLS) to isolate two customers on a shared provider infrastructure. Two PEs share physical links but maintain completely separate routing tables per VRF.

---

## Topology

```
[ce-a1] --RED-- [pe1] --RED-- [pe2] --RED-- [ce-a2]
[ce-b1] --BLUE- [pe1] --BLUE- [pe2] --BLUE- [ce-b2]
```

pe1 and pe2 each maintain two VRFs. Two separate inter-PE links carry each VRF (this is "VRF-Lite" — no MPLS label switching).

### Link addressing

| Link            | Subnet        | Left      | Right     | VRF       |
|-----------------|---------------|-----------|-----------|-----------|
| ce-a1 — pe1     | 10.10.12.0/30 | 10.10.12.1| 10.10.12.2| VRF-RED   |
| pe1 — pe2 (RED) | 10.10.99.0/30 | 10.10.99.1| 10.10.99.2| VRF-RED   |
| pe2 — ce-a2     | 10.10.34.0/30 | 10.10.34.1| 10.10.34.2| VRF-RED   |
| ce-b1 — pe1     | 10.20.12.0/30 | 10.20.12.1| 10.20.12.2| VRF-BLUE  |
| pe1 — pe2 (BLU) | 10.20.99.0/30 | 10.20.99.1| 10.20.99.2| VRF-BLUE  |
| pe2 — ce-b2     | 10.20.34.0/30 | 10.20.34.1| 10.20.34.2| VRF-BLUE  |

### Node reference

| Node  | Loopback     | VRF       | Role         |
|-------|--------------|-----------|--------------|
| ce-a1 | 10.10.0.1/32 | VRF-RED   | Cust A Site 1 |
| ce-a2 | 10.10.0.2/32 | VRF-RED   | Cust A Site 2 |
| ce-b1 | 10.20.0.1/32 | VRF-BLUE  | Cust B Site 1 |
| ce-b2 | 10.20.0.2/32 | VRF-BLUE  | Cust B Site 2 |
| pe1   | 192.168.0.1  | global    | Provider Edge |
| pe2   | 192.168.0.2  | global    | Provider Edge |

### VRF table IDs

| VRF      | Linux table ID |
|----------|----------------|
| VRF-RED  | 100            |
| VRF-BLUE | 200            |

---

## Deploy and access

```bash
sudo containerlab deploy --topo topology.yml

# Access PE nodes
docker exec -it clab-vrf-lite-pe1 vtysh
docker exec -it clab-vrf-lite-pe1 bash    # Linux shell for ip commands
```

---

## Step 1 — Review the pre-configured setup

The VRF Linux netdevs are created automatically by setup.sh when the container starts. Verify on pe1:

```bash
docker exec -it clab-vrf-lite-pe1 bash
ip link show type vrf
# Should show: VRF-RED (table 100) and VRF-BLUE (table 200)

ip link show master VRF-RED
# Shows which interfaces are enslaved to VRF-RED
```

In vtysh on pe1, the interface VRF assignments are already in frr.conf:
```
show interface eth1
# Description should show "VRF-RED"

show ip route vrf VRF-RED
# Should show directly-connected prefixes but no loopback routes yet
```

---

## Step 2 — Configure static routes within each VRF on pe1

```
! In vtysh on pe1:

! VRF-RED routes
ip route 10.10.0.1/32 10.10.12.1 vrf VRF-RED
ip route 10.10.0.2/32 10.10.99.2 vrf VRF-RED

! VRF-BLUE routes
ip route 10.20.0.1/32 10.20.12.1 vrf VRF-BLUE
ip route 10.20.0.2/32 10.20.99.2 vrf VRF-BLUE
```

---

## Step 3 — Configure static routes within each VRF on pe2

```
! In vtysh on pe2:

! VRF-RED routes
ip route 10.10.0.1/32 10.10.99.1 vrf VRF-RED
ip route 10.10.0.2/32 10.10.34.2 vrf VRF-RED

! VRF-BLUE routes
ip route 10.20.0.1/32 10.20.99.1 vrf VRF-BLUE
ip route 10.20.0.2/32 10.20.34.2 vrf VRF-BLUE
```

---

## Verification

```
! On pe1 — separate routing tables per VRF
show ip route vrf VRF-RED
show ip route vrf VRF-BLUE

! End-to-end within VRF-RED (on ce-a1 vtysh):
ping 10.10.0.2 source 10.10.0.1    ! should SUCCEED

! Isolation test — cross-VRF (on ce-a1 vtysh):
ping 10.20.0.1 source 10.10.0.1    ! should FAIL — different VRF

! Verify isolation from pe1 perspective:
show ip route vrf VRF-RED
! 10.20.0.0/x should NOT appear in VRF-RED's table
```

---

## Experiment A — OSPF per VRF (replace statics)

Instead of static routes, run OSPF within each VRF. This is the production-realistic approach.

On **pe1** (and mirror on pe2):
```
router ospf vrf VRF-RED
 ospf router-id 10.10.99.1
 passive-interface eth1
!
interface eth1 vrf VRF-RED
 ip ospf area 0
!
interface eth2 vrf VRF-RED
 ip ospf area 0
```

Remove static routes first: `no ip route 10.10.0.1/32 10.10.12.1 vrf VRF-RED`

Note: each VRF runs a completely independent OSPF process. VRF-RED's OSPF has no awareness of VRF-BLUE's OSPF.

---

## Experiment B — Route leaking between VRFs

VRF isolation is useful for customers, but sometimes a shared service (e.g., a DNS server) needs to be reachable from both VRFs. Route leaking imports a specific prefix from one VRF into another.

Leak ce-a1's loopback (10.10.0.1/32) into VRF-BLUE on pe1:
```
ip route 10.10.0.1/32 10.10.12.1 vrf VRF-BLUE nexthop-vrf VRF-RED
```

Verify: `show ip route vrf VRF-BLUE` — 10.10.0.1/32 should appear.
Then test: from ce-b1, `ping 10.10.0.1` — should now succeed (if pe2 also has the leaked route).

This is a simplified form of route leaking. In production MPLS environments, import/export route targets control this more granularly (see the mpls-sr-isis-bgp lab).

---

## Troubleshooting

**VRF-RED and VRF-BLUE not appearing after deploy**
- setup.sh runs `vtysh -b` — check that vtysh can apply the config
- `docker exec clab-vrf-lite-pe1 bash -c "ip link show type vrf"`

**Interface not in the VRF routing table**
- In FRR, `interface eth1 vrf VRF-RED` in frr.conf assigns the interface to the VRF
- Verify: `show interface eth1` in vtysh — should show the VRF name

**Routes in VRF table but ping still fails**
- Check the CE's default route points to the PE's IP in the correct VRF subnet
- `show ip route vrf VRF-RED` on both pe1 and pe2 — both must have routes in both directions

**Cross-VRF ping unexpectedly succeeds**
- Verify the VRF table IDs are different (100 vs 200)
- `ip rule show` in bash — each VRF should have its own routing policy rule
