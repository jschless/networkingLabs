# Getting Started

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| OS | Linux (Ubuntu 20.04+, Debian 11+) or macOS with Docker Desktop |
| Docker | 20.10+ |
| ContainerLab | 0.50+ |
| RAM | 8 GB (16 GB recommended for enterprise/DC labs) |
| Disk | 20 GB free |

## Install ContainerLab

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
containerlab version
```

## Build the FRR Image

Required for **all FRR-based labs** (most labs):

```bash
docker build -t frr-lab:local images/frr/
```

## Custom Images

Some labs require additional custom images. Build only what you need:

| Image | Labs | Build Command |
|-------|------|---------------|
| `ipsec-lab:local` | ipsec-basics, gre-ipsec, flexvpn-basics | `docker build -t ipsec-lab:local labs/ipsec-basics/` |
| `wireguard-lab:local` | wireguard | `docker build -t wireguard-lab:local labs/wireguard/` |
| `nac-lab:local` | dot1x-nac | `docker build -t nac-lab:local labs/dot1x-nac/` |
| `macsec-lab:local` | macsec-basics | `docker build -t macsec-lab:local labs/macsec-basics/` |
| `assurance-lab:local` | network-assurance | `docker build -t assurance-lab:local labs/network-assurance/` |
| `qos-lab:local` | qos-enterprise | `docker build -t qos-lab:local labs/qos-enterprise/` |

## Arista cEOS

Import the cEOS image once (requires a free Arista account to download):

```bash
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F
```

Used by: `gre-ceos`, `dmvpn-ceos`, `dmvpn-phase2`, `dmvpn-phase3`, `spine-leaf-ceos`,
`evpn-vxlan-ceos`, `evpn-border-ceos`, `vrf-lite`, `ha-network-design-ceos`, all `enterprise-*` labs,
`stp-operations`, `lacp-etherchannel`, `dot1x-ceos-practice`.

## Nokia SR-Linux

```bash
docker pull ghcr.io/nokia/srlinux:latest
```

Used by: `mpls-sr-srlinux`, `vxlan-evpn-srlinux`.

---

## Your First Lab: ospf-multiarea

```bash
# 1. Deploy
sudo containerlab deploy -t labs/ospf-multiarea/topology.clab.yml

# 2. Check what's running
./scripts/lab.sh list ospf-multiarea

# 3. Open r1's FRR CLI
docker exec -it clab-ospf-multiarea-r1 vtysh

# 4. Verify OSPF (wait ~15 seconds for convergence)
show ip ospf neighbor
show ip ospf database
show ip route ospf

# 5. Exit and destroy
exit
sudo containerlab destroy -t labs/ospf-multiarea/topology.clab.yml --cleanup
```

!!! tip "Practice vs Reference"
    **Practice labs** have IP addresses pre-configured but routing left for you to implement.
    Each `frr.conf` contains commented hints showing the expected config.

    **Reference labs** are fully working — deploy and explore.

## Helper Script

The `scripts/lab.sh` wrapper simplifies common operations:

```bash
./scripts/lab.sh deploy <name>         # deploy a lab (handles sudo)
./scripts/lab.sh destroy <name>        # destroy and clean up
./scripts/lab.sh list <name>           # list nodes and IPs
./scripts/lab.sh vtysh <name> <node>   # open FRR CLI
./scripts/lab.sh bash <name> <node>    # open shell
./scripts/lab.sh cmd <name> <node> <cmd>  # run a command
```
