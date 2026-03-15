# DMVPN Phase 3 — VyOS Practice Lab

Configure DMVPN Phase 3 on VyOS using mGRE, NHRP shortcuts, OSPF point-to-multipoint, and route summarization on the hub. The hub is already configured; each spoke has only its WAN IP, loopback LAN, and base GRE tunnel. Your job is to finish the NHRP and OSPF configuration on the spokes.

This lab is VyOS-native:

- `configure`
- `set ...`
- `commit`
- `save`

## Topology

```mermaid
flowchart TB
    brwan[("br-wan\n10.0.0.0/24\nNBMA WAN")]
    hub["hub\neth1: 10.0.0.1\ntun0: 172.16.0.1\nsummary 192.168.0.0/16"]
    spoke1["spoke1\neth1: 10.0.0.11\ntun0: 172.16.0.11\nlo: 192.168.1.1/24"]
    spoke2["spoke2\neth1: 10.0.0.12\ntun0: 172.16.0.12\nlo: 192.168.2.1/24"]
    spoke3["spoke3\neth1: 10.0.0.13\ntun0: 172.16.0.13\nlo: 192.168.3.1/24"]

    hub --- brwan
    spoke1 --- brwan
    spoke2 --- brwan
    spoke3 --- brwan
```

## Deploy And Access

```bash
sudo containerlab deploy -t labs/dmvpn-phase3/topology.clab.yml

./scripts/lab.sh cli dmvpn-phase3 hub
./scripts/lab.sh cli dmvpn-phase3 spoke1
```

`lab.sh cli` drops you into the VyOS admin shell.

## What Is Pre-Configured

- Hub WAN IP and mGRE tunnel
- Hub NHRP NHS role with `redirect`
- Hub OSPF point-to-multipoint
- Hub static blackhole summary `192.168.0.0/16`
- Hub OSPF redistribution of that summary
- Spoke WAN IPs
- Spoke loopback LANs
- Spoke GRE tunnel interfaces with source set to `eth1`

## Configure Each Spoke

On `spoke1`:

```vyos
configure

set protocols nhrp tunnel tun0 network-id '1'
set protocols nhrp tunnel tun0 holdtime '300'
set protocols nhrp tunnel tun0 nhs tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 map tunnel-ip '172.16.0.1' nbma '10.0.0.1'
set protocols nhrp tunnel tun0 multicast '10.0.0.1'
set protocols nhrp tunnel tun0 registration-no-unique
set protocols nhrp tunnel tun0 shortcut

set protocols ospf parameters router-id '10.0.0.11'
set protocols ospf area 0 network '172.16.0.11/32'
set protocols ospf area 0 network '192.168.1.0/24'
set protocols ospf interface eth1 passive
set protocols ospf interface tun0 network 'point-to-multipoint'

commit
save
exit
```

Repeat for `spoke2` and `spoke3` with their own router IDs, tunnel /32s, and LAN subnets.

## Verify

On `hub`:

```vyos
show ip nhrp
show ip ospf neighbor
show ip route ospf
```

On `spoke1`:

```vyos
show ip route 192.168.0.0/16
ping 192.168.2.1 count 3
show ip nhrp
```

Phase 3 expectation:

- spokes initially learn the summary `192.168.0.0/16` via the hub
- the first spoke-to-spoke packets follow the hub path
- NHRP installs a more-specific shortcut for the active remote LAN, which overrides the summary

## Automated Check

```bash
./scripts/lab.sh check dmvpn-phase3
```

## Cleanup

```bash
sudo containerlab destroy -t labs/dmvpn-phase3/topology.clab.yml --cleanup
```
