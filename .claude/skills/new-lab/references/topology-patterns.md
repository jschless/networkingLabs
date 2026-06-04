# Common Topology Patterns

## Two-router point-to-point

```
[r1] --- [r2]
```

Links: 1 (eth1↔eth1)
Use for: simple protocol basics, BFD, GRE tunnels

## Linear chain (3-4 nodes)

```
[r1] --- [r2] --- [r3] --- [r4]
```

Links: eth1↔eth1, eth2↔eth1, eth2↔eth1
Use for: OSPF multi-area, IS-IS multi-area, BGP path selection, redistribution

## Diamond (4 nodes)

```
        [isp1]
       /      \
[ce1]          [ce2]
       \      /
        [isp2]
```

Links: ce1↔isp1, ce1↔isp2, isp1↔ce2, isp2↔ce2
Use for: BGP path selection, route manipulation, dual-homing

## Hub-and-spoke (DMVPN/WireGuard)

```
spoke1 \
spoke2 --[br-wan]-- hub
spoke3 /
```

All on same L2 bridge `br-wan` (ContainerLab network)
Use for: DMVPN, WireGuard, NHRP

## WAN segment (GRE/IPsec)

```
[host-a] --- [gw-a] ---[internet]--- [gw-b] --- [host-b]
```

Links: host-a:eth1↔gw-a:eth1, gw-a:eth2↔internet:eth1, internet:eth2↔gw-b:eth1, gw-b:eth2↔host-b:eth1
Use for: GRE, IPsec, GRE+IPsec

## Spine-leaf (CLOS fabric)

```
[spine1]   [spine2]
  |  \  /  |
  |  /\    |
[leaf1][leaf2][leaf3][leaf4]
```

Each leaf connects to both spines (`/31` point-to-point links)
Use for: BGP ECMP, VXLAN/EVPN fabric

Spine-leaf IP convention:
- `10.1.0.0/31` leaf1↔spine1, `10.2.0.0/31` leaf1↔spine2
- `10.1.0.2/31` leaf2↔spine1, `10.2.0.2/31` leaf2↔spine2
- Increment by 2 per leaf; `10.1.x` = spine1 fabric, `10.2.x` = spine2 fabric

## IP addressing conventions

| Range | Use |
|-------|-----|
| 10.0.0.N/32 | Loopback N on router N |
| 10.1.12.0/30 | Link between r1 and r2 (.1 = r1, .2 = r2) |
| 10.1.23.0/30 | Link between r2 and r3 |
| 10.1.34.0/30 | Link between r3 and r4 |
| 192.168.1.0/24 | LAN A (host-a side) |
| 192.168.2.0/24 | LAN B (host-b side) |
| 203.0.113.0/30 | WAN A (gw-a ↔ internet) |
| 203.0.113.4/30 | WAN B (gw-b ↔ internet) |
| 10.255.0.0/24 | Tunnel overlay (DMVPN, etc.) |

## Node naming conventions

| Type | Names |
|------|-------|
| Generic routers | r1, r2, r3, r4 |
| Spine-leaf fabric | spine1, spine2, leaf1–leaf4 |
| BGP peers | ce1, ce2, isp1, isp2, asbr, bgp1 |
| GRE/IPsec | host-a, gw-a, internet, gw-b, host-b |
| DMVPN | hub, spoke1, spoke2, spoke3 |
| VXLAN | spine, vtep1, vtep2, host1, host2 |
| EVPN fabric | spine1, spine2, leaf1–leaf4, host-a1, host-b1, etc. |
| Redistribution | r1, asbr, bgp1, bgp2 |
