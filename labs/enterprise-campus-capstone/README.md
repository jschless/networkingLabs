# Enterprise Campus Capstone

Practice lab: configure a full 3-tier campus network from scratch. IPs and interfaces are pre-configured; you implement all routing, redundancy, and switching protocols.

See `labs/enterprise-campus/` for the fully-working reference solution.

## Topology

```
                       [isp]  AS65500
                         |  203.0.113.0/30
                      [edge]  AS65100
                      /    \
          10.255.1.0/30    10.255.2.0/30
               /                \
          [core1]----10.255.3.0/30----[core2]
           /  \                       /  \
    10.0.13   10.0.14         10.0.23   10.0.24
      /30        /30             /30        /30
  [dist1]--------------------[dist2]
  /      \                  /      \
[acc1] [acc2]          [acc3] [acc4]
  |                      |
[client-a]           [client-b]
VLAN 10               VLAN 20
10.10.10.11           10.20.20.11
```

## Node / Link Table

| Node    | Role          | Loopback       | AS    |
|---------|---------------|----------------|-------|
| isp     | Upstream ISP  | 1.1.1.1/32     | 65500 |
| edge    | Internet edge | 10.0.0.1/32    | 65100 |
| core1   | Core L3       | 10.0.0.2/32    | —     |
| core2   | Core L3       | 10.0.0.3/32    | —     |
| dist1   | ABR + VRRP    | 10.0.0.4/32    | —     |
| dist2   | ABR + VRRP    | 10.0.0.5/32    | —     |
| acc1–4  | L2 access     | —              | —     |

| Link              | Subnet            |
|-------------------|-------------------|
| isp – edge        | 203.0.113.0/30    |
| edge – core1      | 10.255.1.0/30     |
| edge – core2      | 10.255.2.0/30     |
| core1 – core2     | 10.255.3.0/30     |
| core1 – dist1     | 10.0.13.0/30      |
| core1 – dist2     | 10.0.14.0/30      |
| core2 – dist1     | 10.0.23.0/30      |
| core2 – dist2     | 10.0.24.0/30      |

| VLAN | Name      | Subnet           | VRRP VIP    |
|------|-----------|------------------|-------------|
| 10   | corporate | 10.10.10.0/24    | 10.10.10.1  |
| 20   | voice     | 10.20.20.0/24    | 10.20.20.1  |
| 30   | guest     | 10.30.30.0/24    | 10.30.30.1  |
| 99   | mgmt      | 192.168.99.0/24  | 192.168.99.1|

## What's pre-configured

- All interface IPs, `no switchport`, descriptions
- VLAN definitions on dist/acc nodes
- Trunk port configs (allowed VLANs, mode trunk)
- SVI IP addresses on dist1/dist2 (without VRRP)
- `spanning-tree mode rstp` on dist/acc nodes
- isp node: fully configured (eBGP to edge, advertises default route)
- Linux client IPs and default routes

## Your Tasks

### edge
1. **OSPF area 0** — process 1, passive-interface default, activate Ethernet2/3, network loopback + both core links, `default-information originate always`
2. **BGP prefix-list + route-map** — `ip prefix-list ENTERPRISE-OUT` matching 198.51.100.0/24, `route-map BGP-TO-ISP permit 10`
3. **eBGP to ISP** — `router bgp 65100`, peer 203.0.113.1 AS65500, black-hole static route, `network 198.51.100.0/24`, apply route-map outbound

### core1, core2
1. **OSPF area 0** — all 4 Ethernet interfaces active, network loopback + all 4 links in area 0

### dist1
1. **STP priorities** — primary root (4096) for VLANs 10/30/99, secondary (8192) for VLAN 20
2. **VRRP** — active (120) on VLANs 10/30/99, standby (100) on VLAN 20, VIP = x.x.x.1
3. **OSPF ABR** — Ethernet1/2 active in area 0, SVIs in area 1

### dist2
1. **STP priorities** — primary root (4096) for VLAN 20, secondary (8192) for VLANs 10/30/99
2. **VRRP** — active (120) on VLAN 20, standby (100) on VLANs 10/30/99
3. **OSPF ABR** — same structure as dist1

### acc1, acc3
1. **STP portfast** — `spanning-tree portfast` on the client-facing access port (Ethernet2)

## Verification

```bash
# Access nodes
docker exec -it clab-enterprise-campus-capstone-edge Cli
docker exec -it clab-enterprise-campus-capstone-core1 Cli
docker exec -it clab-enterprise-campus-capstone-dist1 Cli

# OSPF neighbors (expect Full on all p2p links)
show ip ospf neighbor

# BGP session to ISP
show bgp summary

# VRRP state (dist1 should be Master on VLAN 10/30/99)
show vrrp

# STP root (dist1 should be root for VLAN 10/30)
show spanning-tree vlan 10

# End-to-end: ping from client-a to internet (via ISP loopback)
docker exec -it clab-enterprise-campus-capstone-client-a ping 1.1.1.1

# Cross-VLAN: client-a (VLAN 10) → client-b (VLAN 20)
docker exec -it clab-enterprise-campus-capstone-client-a ping 10.20.20.11
```

## Deploy

```bash
sudo containerlab deploy -t labs/enterprise-campus-capstone/topology.clab.yml
# or
./scripts/lab.sh deploy enterprise-campus-capstone
```
