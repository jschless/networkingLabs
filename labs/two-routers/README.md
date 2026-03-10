# Lab: two-routers

## Purpose
The simplest possible ContainerLab lab — two cEOS routers connected back-to-back with OSPF.
Use this as a starting point to understand how ContainerLab works, how cEOS configuration
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
# Access r1's cEOS CLI
docker exec -it clab-two-routers-r1 Cli

# Or run a single command
docker exec clab-two-routers-r1 Cli -c "show ip ospf neighbor"
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

This lab demonstrates the core ContainerLab + cEOS workflow:

- **topology.yml**: defines nodes and links; ContainerLab creates veth pairs between containers
- **startup-config**: bind-mounted into `/etc/frr/startup-config`; cEOS reads this at startup
- **daemons**: controls which cEOS daemons run (zebra, ospfd, bgpd, etc.)
- **Cli.conf**: `service integrated-Cli-config` writes `Cli -w` changes to startup-config

OSPF forms an adjacency over the point-to-point link and each router learns the other's
routes. This is the foundation that all other labs in this collection build on.
