# Self-Hosted Lab Environment

A local, self-hosted lab environment for hands-on practice across **three tracks**:

1. **Networking** — routing, switching, data center, tunnels/VPN, enterprise design
   (OSPF, BGP, IS-IS, EIGRP, MPLS/SR, VXLAN/EVPN, …) on
   [FRRouting](https://frrouting.org/), [Arista cEOS](https://www.arista.com/),
   [VyOS](https://vyos.io/), [Nokia SR-Linux](https://learn.srlinux.dev/), and
   [FortiGate](https://www.fortinet.com/).
2. **Security Operations (SOC)** — DMZ visibility, Zeek, Suricata, YARA, SIEM ingest,
   dashboards, threat intel, and incident-response workflow.
3. **Enterprise IT 101** — build a complete mini enterprise domain from scratch:
   Active Directory, PKI, DNS, DHCP, email, SSO/MFA, file shares, web proxy, RADIUS.

Tracks 1 and 2 run on [ContainerLab](https://containerlab.dev/) (`labs/`).
Track 3 is a separate [Docker Compose](https://docs.docker.com/compose/) curriculum
(`enterprise-it-101/`) — same machine, different tooling.

> 📖 **The full catalog, study paths, and reference live in the docs site.**
> Build it locally with `mkdocs serve` (see [docs/getting-started.md](docs/getting-started.md))
> or browse the [`docs/`](docs/) folder directly.

---

## The three tracks

| Track | Location | Tooling | Helper | Start here |
|-------|----------|---------|--------|------------|
| **Networking** (routing, switching, DC, VPN, enterprise, debug) | `labs/` | ContainerLab | `scripts/lab.sh` | [docs/tracks](docs/tracks/) |
| **Security Operations (SOC)** | `labs/soc-*` | ContainerLab | `scripts/lab.sh` | [docs/tracks/security-infrastructure](docs/tracks/security-infrastructure/index.md) |
| **Enterprise IT 101** | `enterprise-it-101/` | Docker Compose | `enterprise-it-101/eit.sh` | [enterprise-it-101/README.md](enterprise-it-101/README.md) |

The first two share one workflow (ContainerLab + `scripts/lab.sh`); Enterprise IT 101 is
service-oriented and uses its own Docker Compose workflow. They are intentionally separate —
don't expect `scripts/lab.sh` to drive the Enterprise IT labs (use `eit.sh` instead).

---

## Quick Start

### Networking & SOC labs (ContainerLab)

```bash
# One-time: build the enhanced FRR image used by most labs
docker build -t frr-lab:local images/frr/

# Deploy a lab
sudo containerlab deploy -t labs/<name>/topology.clab.yml
#   or: ./scripts/lab.sh deploy <name>

# Attach to a node's CLI (the helper picks vtysh / Cli / sr_cli automatically)
./scripts/lab.sh cli <name> <node>

# Destroy
sudo containerlab destroy -t labs/<name>/topology.clab.yml --cleanup
#   or: ./scripts/lab.sh destroy <name>
```

Example:

```bash
sudo containerlab deploy -t labs/eigrp-basics/topology.clab.yml
docker exec -it clab-eigrp-basics-r1 vtysh
sudo containerlab destroy -t labs/eigrp-basics/topology.clab.yml --cleanup
```

Some labs need additional custom images (cEOS, VyOS, SR-Linux, FortiGate, SOC tooling).
See **[docs/getting-started.md](docs/getting-started.md)** for the full prerequisite and
image-build matrix.

### Enterprise IT 101 (Docker Compose)

```bash
cd enterprise-it-101
./eit.sh build          # build the custom images once
./eit.sh up 01          # bring up Lab 01 (Active Directory)
./eit.sh exec 01 dc1 bash
./eit.sh down 01        # tear it down
```

See **[enterprise-it-101/README.md](enterprise-it-101/README.md)** for the curriculum.

---

## How the labs work (networking & SOC)

Each lab directory contains a ContainerLab topology, a README guide, and per-node configs:

```
labs/<name>/
  topology.clab.yml   <- ContainerLab topology (nodes + links)
  README.md           <- Lab guide: tasks and verification commands
  configs/<node>/     <- frr.conf / startup-config / setup.sh per node
```

- **Practice labs** — IP addressing is pre-configured; you implement the protocol/feature.
- **Reference labs** — fully working out of the box; deploy and explore.
- **Debug labs** — a working topology with one intentional bug; diagnose from symptoms.
- **Capstones** — larger end-to-end labs combining multiple features.

---

## Find your way

| I want to… | Go to |
|------------|-------|
| Install prerequisites & build images | [docs/getting-started.md](docs/getting-started.md) |
| Understand lab anatomy & startup | [docs/how-it-works.md](docs/how-it-works.md) |
| Follow a guided learning path | [docs/study-paths.md](docs/study-paths.md) |
| Look up show commands & node naming | [docs/quick-reference.md](docs/quick-reference.md) |
| Browse all labs by track | [docs/tracks/](docs/tracks/) |
| Build the full enterprise IT stack | [enterprise-it-101/README.md](enterprise-it-101/README.md) |
| Add a lab | [docs/contributing.md](docs/contributing.md) |

---

## Tips

- **Wait for convergence** after deploy — OSPF/BGP need 15–60 seconds.
- **cEOS**: use `Cli` (capital C); **SR-Linux**: use `sr_cli`; **FRR**: use `vtysh`.
  `./scripts/lab.sh cli <lab> <node>` picks the right one for you.
- **Custom images**: build the required image before deploying a lab that needs one
  (see [docs/getting-started.md](docs/getting-started.md)).
- **MPLS labs**: kernel label space is set via `sysctls` in `topology.clab.yml`.
- ContainerLab names containers `clab-<lab>-<node>`; Enterprise IT 101 uses role names
  (`dc1`, `mail1`, …).
