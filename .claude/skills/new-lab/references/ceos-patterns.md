# cEOS Config Patterns

## Global (always required)

```
no aaa root
!
ip routing
```

## Interfaces

```
interface Loopback0
 ip address 10.0.0.1/32
!
interface Ethernet1
 no switchport              ! REQUIRED — cEOS defaults to L2
 description to r2
 ip address 10.1.12.1/30
```

## OSPF (EOS)

```
router ospf 1
 router-id 10.0.0.1
 passive-interface Loopback0
!
interface Ethernet1
 ip ospf area 0
!
interface Loopback0
 ip ospf area 0
 ip ospf passive
```

Stub area: `area 2 stub` under `router ospf 1` on ABR and internal routers
Totally stub: `area 2 stub no-summary` on ABR only

OSPF over tunnel: `tunnel routes` under `router ospf 1` (EOS default is `no tunnel routes`)

## BGP (EOS)

```
router bgp 65001
 router-id 10.0.0.1
 neighbor 10.1.12.2 remote-as 65002
 neighbor 10.1.12.2 send-community          ! NOT automatic in EOS for eBGP
 neighbor 10.1.12.2 send-community extended ! CRITICAL for EVPN RT exchange
 !
 address-family ipv4
  neighbor 10.1.12.2 activate
```

BGP ECMP: `maximum-paths 4 ecmp 4` + `bgp bestpath as-path multipath-relax`
iBGP next-hop-self: `neighbor X next-hop-self`

## IS-IS (EOS)

```
router isis CORE
 net 49.0001.0000.0000.0001.00
 is-type level-2
!
interface Ethernet1
 isis enable CORE
 isis circuit-type level-2
!
interface Loopback0
 isis enable CORE
 isis passive
```

## BFD

```
! Enable BFD on OSPF interface
interface Ethernet1
 ip ospf bfd

! Enable BFD on BGP neighbor
router bgp 65001
 neighbor 10.1.12.2 bfd
```

## GRE Tunnel (EOS — verified 4.35.2F)

```
interface Tunnel0
 tunnel source Ethernet1
 tunnel destination 203.0.113.2
 tunnel path-mtu-discovery     ! REQUIRED before setting TTL
 tunnel ttl 255                ! Fix OSPF TTL=1 drop issue
 ip address 172.16.0.1/30
!
router ospf 1
 tunnel routes                 ! EOS default is "no tunnel routes"
```

**iptables fix for transit traffic** (in topology.yml exec, LAN-side interface):
```yaml
exec:
  - bash -c "iptables -D EOS_FORWARD -i eth2 -j DROP 2>/dev/null || true"
```

## mGRE/DMVPN (EOS)

Hub:
```
interface Tunnel0
 tunnel mode gre multipoint
 tunnel source Ethernet1
 ip nhrp network-id 1
 ip nhrp redirect
 ip address 10.255.0.1/24
```

Spoke:
```
interface Tunnel0
 tunnel mode gre multipoint
 tunnel source Ethernet1
 ip nhrp network-id 1
 ip nhrp nhs 10.255.0.1 nbma <hub-wan-ip> multicast
 ip nhrp map 10.255.0.1 <hub-wan-ip>
 ip address 10.255.0.N/24
```

## VRF-Lite (EOS)

```
vrf instance VRF-RED
!
ip routing vrf VRF-RED
!
interface Ethernet1
 vrf VRF-RED               ! Set VRF BEFORE ip address
 no switchport
 ip address 10.10.12.1/30
!
ip route vrf VRF-RED 10.10.0.0/24 10.10.12.2
```

Note: changing VRF on an interface in EOS clears the IP — must re-add after.

## VXLAN/EVPN (EOS)

```
vlan 10
!
interface Vxlan1
 vxlan source-interface Loopback0
 vxlan udp-port 4789
 vxlan vlan 10 vni 10010
 vxlan vrf TENANT-A vni 50001
!
ip virtual-router mac-address 00:1c:73:aa:aa:aa
!
interface Vlan10
 vrf TENANT-A
 ip address virtual 10.10.10.1/24
!
router bgp 65001
 neighbor SPINES send-community extended   ! CRITICAL — not automatic
 !
 address-family evpn
  neighbor SPINES activate
 !
 vrf TENANT-A
  rd 10.0.0.1:50001
  route-target import evpn 65000:50001
  route-target export evpn 65000:50001
  redistribute connected
```

## IP SLA / Tracking (EOS)

```
ip sla 1
 icmp-echo 8.8.8.8
 frequency 5
!
ip sla schedule 1 start-time now lifetime forever
!
track 1 ip sla 1 reachability
!
ip route 0.0.0.0/0 203.0.113.1 tracked 1
ip route 0.0.0.0/0 203.0.113.5 10    ! Backup with higher metric
```

## VRRP (EOS)

```
interface Ethernet1
 vrrp 1 priority-level 110
 vrrp 1 ip 10.0.0.1
 vrrp 1 timers advertise 1
```
