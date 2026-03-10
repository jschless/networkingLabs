# FRR Config Patterns (frrouting/frr:latest = 8.4_git)

## daemons file (shared across nodes unless node-specific)

```
frr_profile="traditional"
bgpd=no
ospfd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
bfdd=no
fabricd=no
vrrpd=no
pathd=no
vtysh_enable=yes
zebra_options="  -A 127.0.0.1 -s 90000000"
bgpd_options="   -A 127.0.0.1"
ospfd_options="  -A 127.0.0.1"
isisd_options="  -A 127.0.0.1"
staticd=yes
staticd_options="-A 127.0.0.1"
```

Enable needed daemons by setting `=yes` (e.g., `ospfd=yes`, `bgpd=yes`).

## vtysh.conf (always the same)

```
service integrated-vtysh-config
```

## topology.yml bind mounts (FRR)

```yaml
binds:
  - configs/daemons:/etc/frr/daemons
  - configs/vtysh.conf:/etc/frr/vtysh.conf
  - configs/r1/frr.conf:/etc/frr/frr.conf
exec:
  - vtysh -b
```

**Always include `exec: - vtysh -b`** — forces FRR to re-apply config after veth pairs are created (race condition fix).

## OSPF (FRR 8.4)

```
router ospf
 ospf router-id 10.0.0.1
!
interface eth1
 ip ospf area 0
!
interface lo
 ip ospf area 0
 ip ospf passive
```

## BGP (FRR 8.4)

```
router bgp 65001
 no bgp ebgp-requires-policy    ! Required — FRR 8.x enforces policy by default
 bgp router-id 10.0.0.1
 neighbor 10.1.12.2 remote-as 65002
 !
 address-family ipv4 unicast
  network 10.0.0.1/32
 exit-address-family
```

iBGP next-hop-self: `neighbor X next-hop-self`
BGP VPNv4: `address-family ipv4 vpn` (NOT `address-family vpnv4`)

## IS-IS (FRR 8.4)

```
router isis CORE
 net 49.0001.0000.0000.0001.00
 is-type level-2
!
interface eth1
 ip router isis CORE    ! NOT "isis enable CORE"
!
interface lo
 ip router isis CORE
 isis passive
```

## MPLS SR (FRR 8.4)

Topology requires `sysctls: net.mpls.platform_labels: "1048575"` (NOT in exec).

```
router isis CORE
 segment-routing on
 segment-routing global-block 16000 23999
 !
 segment-routing prefix 10.0.0.1/32 index 1
!
interface eth1
 mpls enable
```

## VRF Setup (FRR — use setup.sh, not inline exec)

setup.sh:
```bash
#!/bin/bash
ip link add VRF-A type vrf table 100
ip link set VRF-A up
ip link set eth1 master VRF-A
vtysh -b
```

In topology.yml:
```yaml
binds:
  - configs/pe1/setup.sh:/setup.sh
exec:
  - bash /setup.sh
```

## NHRP/DMVPN (FRR)

```
interface tun0
 tunnel source eth1
 tunnel mode gre multipoint
 ip nhrp network-id 1
 ip nhrp nhs 10.255.0.1 nbma <hub-wan-ip> multicast dynamic
 ip address 10.255.0.2/24
!
interface lo
 ip address 10.0.0.2/32
```

## Key FRR 8.4 Syntax Differences from Older Docs

| Feature | Correct | Wrong |
|---------|---------|-------|
| IS-IS on interface | `ip router isis CORE` | `isis enable CORE` |
| BGP VPNv4 AF | `address-family ipv4 vpn` | `address-family vpnv4` |
| eBGP policy | add `no bgp ebgp-requires-policy` | (omit = broken) |
| MPLS on interface | `mpls enable` | various wrong forms |
