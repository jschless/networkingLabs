# Quick Reference

## FRR (vtysh)

```
show version                          # FRR version and enabled daemons
show running-config                   # current config
write memory                          # save config to frr.conf

show ip ospf neighbor                 # OSPF adjacency state
show ip ospf database                 # OSPF LSDB
show ip route ospf                    # OSPF routes in RIB

show bgp ipv4 unicast summary         # BGP session state and prefix counts
show bgp ipv4 unicast                 # full BGP table
show ip route bgp                     # BGP routes in RIB

show isis neighbor                    # IS-IS adjacency state
show isis database                    # IS-IS LSDB

show mpls table                       # MPLS forwarding table
show bfd peers                        # BFD session state
show ip route                         # full routing table
show ip route vrf <name>              # routes in a VRF
show vrf                              # VRF summary
```

## Arista cEOS (Cli)

```
show version                          # EOS version
show running-config                   # current config

show ip ospf neighbor                 # OSPF adjacency state
show bgp ipv4 unicast summary         # BGP session state
show bgp ipv4 unicast                 # full BGP table
show vxlan vtep                       # VXLAN remote VTEPs
show bgp evpn                         # EVPN routes
show vrf                              # VRF summary
show ip route vrf <name>              # routes in a specific VRF
show interfaces Tunnel0               # tunnel interface state
show ip nhrp                          # NHRP mappings (DMVPN)
show spanning-tree                    # STP state
show lacp                             # LACP/EtherChannel
```

## Nokia SR-Linux (sr_cli)

```
show version
show network-instance default route-table
show bgp neighbor
show tunnel-interface
show network-instance <name> route-table
```

## ContainerLab Commands

```bash
# Deploy
sudo containerlab deploy -t labs/<name>/topology.clab.yml

# Destroy and remove containers
sudo containerlab destroy -t labs/<name>/topology.clab.yml --cleanup

# List running containers
sudo containerlab inspect

# Helper script
./scripts/lab.sh deploy <name>
./scripts/lab.sh destroy <name>
./scripts/lab.sh list <name>
./scripts/lab.sh vtysh <name> <node>
./scripts/lab.sh bash <name> <node>
./scripts/lab.sh cmd <name> <node> <command>
./scripts/lab.sh capture <name> <node> <iface> [filter]
```

## Node Naming Conventions

| Name | Role |
|------|------|
| `r1`, `r2`, ... | Generic routers |
| `ce1`, `ce2` | Customer Edge |
| `pe1`, `pe2` | Provider Edge |
| `p1`, `p2` | Provider core (transit) |
| `rr1` | BGP Route Reflector |
| `spine1`, `spine2` | DC spine switches |
| `leaf1`–`leaf4` | DC leaf switches |
| `vtep1`, `vtep2` | VXLAN Tunnel Endpoints |
| `gw-a`, `gw-b` | Gateway / edge nodes in VPN labs |
| `hub`, `spoke1`–`spoke3` | DMVPN hub and spokes |
| `host-a`, `host-b` | End hosts (test traffic source/sink) |
| `edge`, `core1`, `core2` | Enterprise WAN/core nodes |
| `dist1`, `dist2` | Enterprise distribution layer |
