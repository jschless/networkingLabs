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

## Build the FRR Image

Required for the FRR/Linux labs:

```bash
docker build -t frr-lab:local images/frr/
```

## Custom Images

Some labs require additional custom images. Build only what you need:

| Image | Labs | Build Command |
|-------|------|---------------|
| `vyos:local` | ipsec-basics, gre-ipsec, macsec-basics, DMVPN labs | `docker build -t vyos:local -f Dockerfile.vyos .` |
| `ipsec-lab:local` | flexvpn-basics | `docker build -t ipsec-lab:local labs/ipsec-basics/` |
| `wireguard-lab:local` | wireguard | `docker build -t wireguard-lab:local labs/wireguard/` |
| `black-core-tools:local` | black-core-routing | `docker build -t black-core-tools:local labs/black-core-routing/` |
| `nac-lab:local` | dot1x-nac | `docker build -t nac-lab:local labs/dot1x-nac/` |
| `assurance-lab:local` | network-assurance | `docker build -t assurance-lab:local labs/network-assurance/` |
| `qos-lab:local` | qos-enterprise | `docker build -t qos-lab:local labs/qos-enterprise/` |
| `telemetry-lab:local` | telemetry-monitoring-hybrid | `docker build -t telemetry-lab:local labs/telemetry-monitoring-hybrid/` |
| `netbox-automation:local` | network-automation-netbox | `docker build -t netbox-automation:local labs/network-automation-netbox/` |
| `fortigate-tools:local` | fortigate-firewall-capstone | `docker build -t fortigate-tools:local labs/fortigate-firewall-capstone/` |
| `ops-lab:local` | management-access-control, dhcp-dns-troubleshooting, ipv6-access-services | `docker build -t ops-lab:local images/ops-lab/` |
| `enterprise-services-infra:local` | enterprise-services-infra | `docker build -t enterprise-services-infra:local labs/enterprise-services-infra/` |
| `enterprise-tacacs:local` | aaa-ops-troubleshooting | `docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/` |
| `dmz-lab:local` | enterprise-edge-nat-firewall | `docker build -t dmz-lab:local labs/enterprise-edge-nat-firewall/` |
| `enterprise-access-tools:local` | enterprise-access-security | `docker build -t enterprise-access-tools:local labs/enterprise-access-security/` |
| `nac-practice:local` | dot1x-ceos-practice | `docker build -t nac-practice:local labs/dot1x-ceos-practice/` |

## Arista cEOS

Import the cEOS image once (requires a free Arista account to download):

```bash
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F
```

Used by: `gre-basics`, `spine-leaf`,
`vxlan-evpn`, `evpn-border-ceos`, `vrf-lite`, `ha-network-design-ceos`, all `enterprise-*` labs,
`stp-operations`, `lacp-etherchannel`, `dot1x-ceos-practice`.

## VyOS

```bash
docker build -t vyos:local -f Dockerfile.vyos .
```

Used by: `ipsec-basics`, `gre-ipsec`, `macsec-basics`, `dmvpn-phase1`,
`dmvpn-phase2`, `dmvpn-phase3`, `dmvpn-phase3-ipsec-capstone`, `debug-dmvpn-phase1`,
`black-core-routing`.

## FortiGate

Use the downloaded FortiGate image as the source of the FortiGate `qcow2`:

```bash
docker image ls vrnetlab/vr-fortios:4.7.11
```

Used by: `fortigate-firewall-capstone`.

The lab then extracts and runs the VM directly:

```bash
sudo labs/fortigate-firewall-capstone/prepare-bridges.sh
./scripts/lab.sh deploy fortigate-firewall-capstone
labs/fortigate-firewall-capstone/extract-fortios.sh
sudo labs/fortigate-firewall-capstone/start-fgt.sh
```

Note: manual license activation is required before the lab can be completed.

## Nokia SR-Linux

```bash
docker pull ghcr.io/nokia/srlinux:latest
```

Used by: `mpls-sr-srlinux`, `vxlan-evpn-srlinux`.

## Security Operations (SOC) Images

The `soc-*` labs share three custom images:

```bash
docker build -t soc-endpoint:local images/soc-endpoint/
docker build -t soc-sensor:local   images/soc-sensor/
docker build -t soc-attacker:local images/soc-attacker/
```

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
