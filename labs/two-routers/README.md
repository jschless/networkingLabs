# Lab: two-routers

## Purpose
The simplest possible ContainerLab lab — two FRR routers connected back-to-back with OSPF.
Use this as a starting point to understand how ContainerLab works, how FRR configuration
is mounted into containers, and how basic OSPF adjacency forms.

## Topology

```
[r1] ---10.0.0.0/30--- [r2]
10.0.0.1              10.0.0.2
```

| Link | Subnet | r1 IP | r2 IP |
|------|--------|-------|-------|
| r1:eth1 -- r2:eth1 | 10.0.0.0/30 | .1 | .2 |

## Deploy / Destroy

```bash
sudo containerlab deploy -t topology.yml
sudo containerlab destroy -t topology.yml
```

## Connect to Nodes

```bash
# Access r1's FRR CLI
docker exec -it clab-two-routers-r1 vtysh

# Or run a single command
docker exec clab-two-routers-r1 vtysh -c "show ip ospf neighbor"
```

## Verification

```
# On r1 or r2
show ip ospf neighbor       # expect r2 as Full neighbor
show ip ospf interface eth1 # OSPF state on link
show ip route ospf          # learned routes
ping 10.0.0.2               # basic connectivity
```

## Concepts

This lab demonstrates the core ContainerLab + FRR workflow:

- **topology.yml**: defines nodes and links; ContainerLab creates veth pairs between containers
- **frr.conf**: bind-mounted into `/etc/frr/frr.conf`; FRR reads this at startup
- **daemons**: controls which FRR daemons run (zebra, ospfd, bgpd, etc.)
- **vtysh.conf**: `service integrated-vtysh-config` writes `vtysh -w` changes to frr.conf

OSPF forms an adjacency over the point-to-point link and each router learns the other's
routes. This is the foundation that all other labs in this collection build on.
