# Getting Started

## System Requirements

| Requirement | Minimum |
|-------------|---------|
| OS | Linux/amd64 (Ubuntu 20.04+, Debian 11+) or macOS/arm64 (Apple Silicon) with Docker Desktop — both run images natively; see [Provision everything for your architecture](#provision-everything-for-your-architecture) |
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

### Provision everything for your architecture

Both **Intel/Linux (amd64)** and **Apple Silicon (arm64)** are supported for the container labs,
and `scripts/build-images.sh` makes that work by filling each
image tag with content native to the machine it runs on:

```bash
scripts/build-images.sh list   # preview what will run on THIS host, change nothing
scripts/build-images.sh        # build every *:local image, pull multi-arch images,
                               # and import the cEOS tarball for your arch
```

It handles three image classes automatically:

- **`*:local` images** — `docker build` on the host emits native-arch images for free.
- **Multi-arch registry images** — `docker pull` auto-selects your arch (nothing to configure).
- **cEOS** — Arista ships it as a *per-arch* tarball (no multi-arch tag), so the script imports
  the one matching your host and tags it as the canonical `ceos:4.35.2F` that every topology
  references. On arm64 the underlying build is `4.36.1F`, tagged canonically so the labs stay
  portable.

The two things it can't fetch for you are the **cEOS tarball** (licensed — see below) and
**`vyos:local`** (needs a VyOS ISO for your arch, see [vyos.md](platforms/vyos.md)).

> **OPNsense exception:** the OPNsense firewall/VPN labs run external x86-64
> QEMU/KVM appliances and therefore require Linux/amd64 with `/dev/kvm`.

> **Tip:** if you've ever set `DOCKER_DEFAULT_PLATFORM=linux/amd64` (a common Mac workaround),
> `unset` it first — it forces amd64 pulls and silently defeats native arch selection.

### Images you download

#### Freely available (no account)

| Image | Acquire it with | Arch |
|-------|-----------------|------|
| `ghcr.io/nokia/srlinux:latest` | `docker pull ghcr.io/nokia/srlinux:latest` | multi-arch ✅ |
| `quay.io/frrouting/frr:8.4.2` | pulled automatically as the base of `frr-lab:local` and the DMVPN/`sdwan` labs | multi-arch ✅ |
| `quay.io/frrouting/frr:10.5.0` | `enterprise-dual-stack-capstone` ISP edge | multi-arch ✅ |

All other registry images the labs use (`grafana`, `prometheus`/`prom/*`, `postgres`, `redis`,
`nginx`, `netbox`, `keycloak`, `step-ca`, `wazuh`, `opennms`, …) are multi-arch and pulled on
demand — nothing to do.

> **Why quay for FRR:** Docker Hub's `frrouting/frr:latest` is **amd64-only**. The quay.io
> mirror publishes a true multi-arch build (incl. arm64), and tag `8.4.2` keeps the FRR 8.4
> syntax the labs are written against. This is what lets the FRR/DMVPN labs run native on Apple
> Silicon instead of under emulation.

#### Requires a free Arista account

| Image | Acquire it with | Arch |
|-------|-----------------|------|
| `ceos:4.35.2F` | download the tarball (below), then `scripts/build-images.sh ceos` | per-arch tarball |

**Getting the cEOS tarball:**

1. Create a free account at [arista.com](https://www.arista.com/en/user-registration) and log in.
2. Go to **Support → Software Download → cEOS-lab**.
3. Download the tarball for **your host's architecture**:

   - **Intel/Linux (amd64):** `cEOS-lab-4.35.2F.tar` (or `cEOS64-lab-*.tar`)
   - **Apple Silicon (arm64):** `cEOSarm-lab-4.36.1F.tar`
4. Leave it in `~/Downloads` (or set `CEOS_TARBALL_DIR=/path`) and run `scripts/build-images.sh ceos`.
   To import by hand instead: `docker import <tarball> ceos:4.35.2F`.

`ceos` powers most routing, switching, data-center, and enterprise labs. SR-Linux is used only by
`mpls-sr-srlinux` and `vxlan-evpn-srlinux`. OPNsense uses a separate VM flow (see below).

### Images you build

`scripts/build-images.sh` (or `scripts/build-images.sh local`) builds all of these at once,
natively for your architecture. The per-image commands below are for building just what a single
lab needs — many labs combine images (e.g. a cEOS router with an `frr-lab:local` host), so check
the lab README. Every `*:local` image builds from a multi-arch base, so `docker build` produces
amd64 on Intel/Linux and arm64 on Apple Silicon with no changes.

| Image | Used by | Build command |
|-------|---------|---------------|
| `frr-lab:local` | the FRR/Linux labs (most non-cEOS labs) | `docker build -t frr-lab:local images/frr/` |
| `enterprise-dual-stack-tools:local` | `enterprise-dual-stack-capstone` Linux services/endpoints | `docker build -t enterprise-dual-stack-tools:local labs/enterprise-dual-stack-capstone/` |
| `advanced-security-tools:1.0.0` | `advanced-security-architecture` endpoints, WAF/PEP, DNS/proxy/logs | `docker build -t advanced-security-tools:1.0.0 labs/advanced-security-architecture/` (pinned Debian 12.12 digest; pinned nginx/ModSecurity CRS, dnsmasq, Squid, nftables, and rsyslog packages) |
| `advanced-security-fw:1.0.0` | `advanced-security-architecture` stateful gateway and inline IDS/IPS | `docker build -f labs/advanced-security-architecture/Dockerfile.fw -t advanced-security-fw:1.0.0 labs/advanced-security-architecture/` (pinned Suricata 7.0.10 image digest; nftables NFQUEUE) |
| `vyos:local` | `ipsec-basics`, `gre-ipsec`, `macsec-basics`, `black-core-routing`, `mtu-pmtud-troubleshooting`, and the DMVPN labs (`dmvpn-phase1/2/3`, `dmvpn-phase3-ipsec-capstone`, `debug-dmvpn-phase1`) | one-time build from a free VyOS ISO — see [VyOS platform notes](platforms/vyos.md) |
| `ipsec-lab:local` | `ipsec-basics`, `flexvpn-basics` | `docker build -t ipsec-lab:local labs/ipsec-basics/` |
| `wireguard-lab:local` | `wireguard` | `docker build -t wireguard-lab:local labs/wireguard/` |
| `black-core-tools:local` | `black-core-routing` | `docker build -t black-core-tools:local labs/black-core-routing/` |
| `ops-lab:local` | `aaa-ops-troubleshooting`, `anycast-dns`, `dhcp-dns-troubleshooting`, `ipv6-access-services`, `k8s-fabric`, `management-access-control`, `mtu-pmtud-troubleshooting`, `troubleshooting-range-dci-edge`, `troubleshooting-range-hybrid-access`, `ztp-basics` | `docker build -t ops-lab:local images/ops-lab/` (multi-arch Alpine 3.20.10 base pinned by OCI index digest) |
| `rancher/k3s:v1.30.6-k3s1` (pulled) | `k8s-fabric` | `docker pull rancher/k3s:v1.30.6-k3s1` (multi-arch; MetalLB + nginx also pull at deploy — needs internet) |
| `anycast-dns:local` | `anycast-dns` | `docker build -t anycast-dns:local labs/anycast-dns/` |
| `nac-lab:local` | `dot1x-nac` | `docker build -t nac-lab:local labs/dot1x-nac/` |
| `wireless-auth-control:local` | `wireless-auth-control-operations` | `docker build -t wireless-auth-control:local labs/wireless-auth-control-operations/` (pinned Debian 12.12 base; live wired EAPOL/RADIUS only) |
| `carrier-ethernet-tools:1.0.0` | `carrier-ethernet-handoff`, `troubleshooting-range-dci-edge` | `docker build -t carrier-ethernet-tools:1.0.0 labs/carrier-ethernet-handoff/` (pinned Debian 12.12 base; OVS userspace QinQ and Linux test tools) |
| `zt-access-tools:local`, `zt-keycloak:local` | `zero-trust-secure-access` | `docker build -t zt-access-tools:local labs/zero-trust-secure-access/` and `docker build -f labs/zero-trust-secure-access/Dockerfile.keycloak -t zt-keycloak:local labs/zero-trust-secure-access/` (pinned Python 3.12.7, Keycloak 26.0.7, and BusyBox base images) |
| `nac-practice:local` | `dot1x-ceos-practice` | `docker build -t nac-practice:local labs/dot1x-ceos-practice/` |
| `nac-practice-tacacs:local` | `dot1x-ceos-practice` | `docker build -f labs/dot1x-ceos-practice/Dockerfile.tacacs -t nac-practice-tacacs:local labs/dot1x-ceos-practice/` |
| `assurance-lab:local` | `network-assurance` | Build `ops-lab:local` and `assurance-lab:local`, then prepare `ceos:4.35.2F` using the [cEOS platform notes](platforms/ceos.md) |
| `qos-lab:local` | `qos-enterprise` | `docker build -t qos-lab:local labs/qos-enterprise/` |
| `telemetry-lab:local` | `telemetry-monitoring-hybrid` | `docker build -t telemetry-lab:local labs/telemetry-monitoring-hybrid/` |
| `sdwan-lab:local` | `sdwan-concepts` | `docker build -t sdwan-lab:local labs/sdwan-concepts/` |
| `orchestrated-wan-tools:1.0.0` | `orchestrated-wan-overlay` | `docker build -t orchestrated-wan-tools:1.0.0 labs/orchestrated-wan-overlay/` (pinned Debian 12.12 base; mTLS, WireGuard, nftables, and `tc`) |
| `automation-fundamentals:local` | `automation-fundamentals` | `docker build -t automation-fundamentals:local labs/automation-fundamentals/` |
| `network-gitops:local` | `network-gitops-change-pipeline` automation, endpoints, and observer | `docker build -t network-gitops:local labs/network-gitops-change-pipeline/` (digest-pinned Python 3.12.7/Alpine 3.20 base; pinned Jinja2, JSON Schema, pytest, and PyYAML) |
| `lb-lab:local` | `load-balancer-basics` | `docker build -t lb-lab:local labs/load-balancer-basics/` |
| `global-delivery:local` | `global-application-delivery` | `docker build -t global-delivery:local labs/global-application-delivery/` (pinned Alpine 3.22.1 and CoreDNS 1.12.2 bases; HAProxy/nginx/dnsmasq packages pinned) |
| `service-ha:local` | `service-ha` | `docker build -t service-ha:local labs/service-ha/` |
| `netbox-automation:local` | `network-automation-netbox` | `docker build -t netbox-automation:local labs/network-automation-netbox/` |
| `opnsense-tools:local` | `opnsense-ngfw-basics`, `opnsense-ipsec-nat-t` | `docker build -t opnsense-tools:local labs/opnsense-ngfw-basics/` |
| `enterprise-services-infra:local` | `enterprise-services-infra` | `docker build -t enterprise-services-infra:local labs/enterprise-services-infra/` |
| `enterprise-voice-tools:1.0.0` | `enterprise-voice-sip-qos` | `docker build -t enterprise-voice-tools:1.0.0 labs/enterprise-voice-sip-qos/` (digest-pinned Ubuntu 24.04 base; pinned Asterisk 20.6.0 and SIPp 3.7.7) |
| `ot-zone-tools:1.0.0` | `ot-zone-conduit` | `docker build -t ot-zone-tools:1.0.0 labs/ot-zone-conduit/` (digest-pinned Ubuntu 24.04 base; PyModbus 3.11.3, Suricata, nftables, OpenSSH, and passive-mirror tools) |
| `enterprise-tacacs:local` | `aaa-ops-troubleshooting`, `enterprise-services-infra` | `docker build -f labs/enterprise-services-infra/Dockerfile.tacacs -t enterprise-tacacs:local labs/enterprise-services-infra/` |
| `enterprise-access-tools:local` | `enterprise-access-security` | `docker build -t enterprise-access-tools:local labs/enterprise-access-security/` |
| `enterprise-multicast:local` | `enterprise-multicast` | `docker build -t enterprise-multicast:local labs/enterprise-multicast/` |
| `enterprise-wireless-architecture:local` | `enterprise-wireless-architecture` | `docker build -t enterprise-wireless-architecture:local labs/enterprise-wireless-architecture/` |
| `dmz-lab:local` | `enterprise-dmz`, `enterprise-dmz-capstone`, `enterprise-edge-nat-firewall` | `docker build -t dmz-lab:local labs/enterprise-edge-nat-firewall/` |
| `soc-attacker:local`, `soc-endpoint:local`, `soc-sensor:local` | all `soc-*` labs | `docker build -t soc-attacker:local images/soc-attacker/` (repeat for `soc-endpoint`, `soc-sensor`) |
| `suzieq-lab:local` | `suzieq-network-observability` | `docker build -t suzieq-lab:local labs/suzieq-network-observability/` |
| `gcap-node:local` | `enterprise-grand-capstone` | `labs/enterprise-grand-capstone/gcap.sh build` (also ensures the EIT101 service images exist) |
| `cloud-lab:local` | `cloud-hybrid-networking` | `docker build -t cloud-lab:local labs/cloud-hybrid-networking/` (pinned FRR 10.5.0 base plus BIND/nftables tools) |
| `dci-endpoint:local` | `dci-evpn-multisite` | `docker build -t dci-endpoint:local -f labs/dci-evpn-multisite/Dockerfile.endpoint labs/dci-evpn-multisite/` (pinned `alpine:3.22.1` base with iproute2, ping, and tcpdump) |
| `dc-storage-tools:1.0.0` | `dc-storage-networking` | `docker build -t dc-storage-tools:1.0.0 labs/dc-storage-networking/` (Linux/amd64 + KVM; digest-pinned Ubuntu 24.04 base and SHA-256-pinned Ubuntu Noble 20260725 guest; LIO, open-iscsi, multipath, fio, QEMU) |

### Images pulled automatically

Some labs also reference public registry images that `containerlab deploy` pulls on
first use — no build step needed: `frrouting/frr:latest` (helper/bridge nodes in the
DMVPN labs), and `netboxcommunity/netbox:v4.1.11` + `postgres:15` + `redis:7-alpine`
(`network-automation-netbox`).

> **arm64 note:** `nac-practice-tacacs:local` and `enterprise-tacacs:local` build from
> `smcline06/tacacs:latest`, the one **amd64-only** base in the repo. They build and run on
> Apple Silicon under emulation — fine for a lightweight auth daemon, just slower. Everything
> else builds native.

### OPNsense (separate VM flow)

The OPNsense labs run a local QEMU/KVM appliance alongside ContainerLab. Install
the free OPNsense image once, create the reusable base disk, then start each
lab's disposable overlay. See [OPNsense platform notes](platforms/opnsense.md).

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
