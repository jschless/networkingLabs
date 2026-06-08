# Getting Started

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| OS | Linux (Ubuntu 20.04+, Debian 11+) or macOS with Docker Desktop |
| Docker | 20.10+ |
| ContainerLab | 0.50+ |
| RAM | 8 GB (16 GB recommended for larger cEOS/VyOS/enterprise labs) |
| Disk | 20 GB free |

## Install ContainerLab

```bash
bash -c "$(curl -sL https://get.containerlab.dev)"
containerlab version
```

## Images

Every lab's README header lists the exact image(s) it needs — **build or download only those.**
This page is the single authoritative reference. The lists below track what each lab's
`topology.clab.yml` actually references, so if a lab and this table ever disagree, the
topology wins.

### Images you download

| Image | Acquire it with |
|-------|-----------------|
| `ceos:4.35.2F` | `docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F` (needs a free Arista account) |
| `ghcr.io/nokia/srlinux:latest` | `docker pull ghcr.io/nokia/srlinux:latest` |

`ceos` powers most routing, switching, data-center, and enterprise labs. SR-Linux is used only by
`mpls-sr-srlinux` and `vxlan-evpn-srlinux`. FortiGate uses a separate VM flow (see below).

### Images you build

Build only what the lab you're running needs. Many labs combine images (e.g. a cEOS router with an
`frr-lab:local` host), so check the lab README.

| Image | Used by | Build command |
|-------|---------|---------------|
| `frr-lab:local` | the FRR/Linux labs (most non-cEOS labs) | `docker build -t frr-lab:local images/frr/` |
| `vyos:local` | `ipsec-basics`, `gre-ipsec`, `macsec-basics`, `black-core-routing`, and the DMVPN labs (`dmvpn-phase1/2/3`, `dmvpn-phase3-ipsec-capstone`, `debug-dmvpn-phase1`) | `docker build -t vyos:local -f Dockerfile.vyos .` |
| `ipsec-lab:local` | `ipsec-basics`, `flexvpn-basics` | `docker build -t ipsec-lab:local labs/ipsec-basics/` |
| `wireguard-lab:local` | `wireguard` | `docker build -t wireguard-lab:local labs/wireguard/` |
| `black-core-tools:local` | `black-core-routing` | `docker build -t black-core-tools:local labs/black-core-routing/` |
| `ops-lab:local` | `aaa-ops-troubleshooting`, `dhcp-dns-troubleshooting`, `ipv6-access-services`, `management-access-control` | `docker build -t ops-lab:local images/ops-lab/` |
| `nac-lab:local` | `dot1x-nac` | `docker build -t nac-lab:local labs/dot1x-nac/` |
| `nac-practice:local` | `dot1x-ceos-practice` | `docker build -t nac-practice:local labs/dot1x-ceos-practice/` |
| `nac-practice-tacacs:local` | `dot1x-ceos-practice` | `docker build -f labs/dot1x-ceos-practice/Dockerfile.tacacs -t nac-practice-tacacs:local labs/dot1x-ceos-practice/` |
| `assurance-lab:local` | `network-assurance` | `docker build -t assurance-lab:local labs/network-assurance/` |
| `qos-lab:local` | `qos-enterprise` | `docker build -t qos-lab:local labs/qos-enterprise/` |
| `telemetry-lab:local` | `telemetry-monitoring-hybrid` | `docker build -t telemetry-lab:local labs/telemetry-monitoring-hybrid/` |
| `netbox-automation:local` | `network-automation-netbox` | `docker build -t netbox-automation:local labs/network-automation-netbox/` |
| `fortigate-tools:local` | `fortigate-firewall-capstone` | `docker build -t fortigate-tools:local labs/fortigate-firewall-capstone/` |
| `enterprise-services-infra:local` | `enterprise-services-infra` | `docker build -t enterprise-services-infra:local labs/enterprise-services-infra/` |
| `enterprise-tacacs:local` | `aaa-ops-troubleshooting`, `enterprise-services-infra` | `docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/` |
| `enterprise-access-tools:local` | `enterprise-access-security` | `docker build -t enterprise-access-tools:local labs/enterprise-access-security/` |
| `enterprise-multicast:local` | `enterprise-multicast` | `docker build -t enterprise-multicast:local labs/enterprise-multicast/` |
| `enterprise-wireless-architecture:local` | `enterprise-wireless-architecture` | `docker build -t enterprise-wireless-architecture:local labs/enterprise-wireless-architecture/` |
| `dmz-lab:local` | `enterprise-dmz`, `enterprise-dmz-capstone`, `enterprise-edge-nat-firewall` | `docker build -t dmz-lab:local labs/enterprise-edge-nat-firewall/` |
| `soc-attacker:local`, `soc-endpoint:local`, `soc-sensor:local` | all `soc-*` labs | `docker build -t soc-attacker:local images/soc-attacker/` (repeat for `soc-endpoint`, `soc-sensor`) |

### FortiGate (separate VM flow)

`fortigate-firewall-capstone` runs a FortiGate VM rather than a container. Confirm the source image,
then let the lab extract and boot the VM:

```bash
docker image ls vrnetlab/vr-fortios:4.7.11
sudo labs/fortigate-firewall-capstone/prepare-bridges.sh
./scripts/lab.sh deploy fortigate-firewall-capstone
labs/fortigate-firewall-capstone/extract-fortios.sh
sudo labs/fortigate-firewall-capstone/start-fgt.sh
```

Note: manual license activation is required before the lab can be completed.

## Enterprise IT 101 Images

The Enterprise IT 101 track uses Docker Compose and its own helper. Build its images with:

```bash
cd enterprise-it-101 && ./eit.sh build
```

See [enterprise-it-101/README.md](https://github.com/jschless/networkingLabs/tree/main/enterprise-it-101) for that track's workflow.

---

## Your First Lab: eigrp-basics

```bash
# 1. Deploy
sudo containerlab deploy -t labs/eigrp-basics/topology.clab.yml

# 2. Check what's running
./scripts/lab.sh list eigrp-basics

# 3. Open r1's FRR CLI
docker exec -it clab-eigrp-basics-r1 vtysh

# 4. Verify EIGRP (wait ~15 seconds for convergence)
show ip eigrp neighbor
show ip route eigrp

# 5. Exit and destroy
exit
sudo containerlab destroy -t labs/eigrp-basics/topology.clab.yml --cleanup
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
./scripts/lab.sh cli <name> <node>     # open cEOS or VyOS CLI when supported
./scripts/lab.sh bash <name> <node>    # open shell
./scripts/lab.sh cmd <name> <node> <cmd>  # run a command
```
