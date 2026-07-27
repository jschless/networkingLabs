# Self-Hosted Lab Environment

A local, self-hosted lab environment for hands-on practice across **three tracks**, all on
your own machine — no cloud account, no license fees. Deploy, break things, learn.

> One caveat to "no fees": the Arista cEOS image requires a free arista.com account to
> download. Everything else is fully open source.

1. **Networking** — routing, switching, data center, tunnels/VPN, enterprise design
   (OSPF, BGP, IS-IS, EIGRP, MPLS/SR, VXLAN/EVPN, …) on
   [FRRouting](https://frrouting.org/), [Arista cEOS](https://www.arista.com/),
   [VyOS](https://vyos.io/), [Nokia SR-Linux](https://learn.srlinux.dev/), and
   [OPNsense](https://opnsense.org/).
2. **Security Operations (SOC)** — DMZ visibility, Zeek, Suricata, YARA, SIEM ingest,
   dashboards, threat intel, and incident-response workflow.
3. **Enterprise IT 101** — build a complete mini enterprise domain from scratch:
   Active Directory, PKI, DNS, DHCP, email, SSO/MFA, file shares, web proxy, RADIUS.

## The three tracks

| Track | Location | Tooling | Helper |
|-------|----------|---------|--------|
| **Networking** (routing, switching, DC, VPN, enterprise, debug) | `labs/` | ContainerLab | `scripts/lab.sh` |
| **Security Operations (SOC)** | `labs/soc-*` | ContainerLab | `scripts/lab.sh` |
| **Enterprise IT 101** | `enterprise-it-101/` | Docker Compose | `enterprise-it-101/eit.sh` |

The first two share one workflow (ContainerLab + `scripts/lab.sh`); Enterprise IT 101 is
service-oriented and uses its own Docker Compose workflow with `eit.sh`. They are
intentionally separate — don't expect `scripts/lab.sh` to drive the Enterprise IT labs.

## Documentation

**The full catalog, quick start, study paths, and reference live in the docs site:**
**<https://jschless.github.io/networkingLabs/>**

You can also browse the [`docs/`](docs/) folder directly, or build the site locally:

```bash
pip install -r requirements-docs.txt
mkdocs serve     # then open http://127.0.0.1:8000
```

| I want to… | Go to |
|------------|-------|
| Install prerequisites, build images, run my first lab | [docs/getting-started.md](docs/getting-started.md) |
| Browse all labs by track | [docs/index.md](docs/index.md) |
| Follow a guided learning path | [docs/study-paths.md](docs/study-paths.md) |
| Understand lab anatomy & startup | [docs/how-it-works.md](docs/how-it-works.md) |
| Look up show commands & node naming | [docs/quick-reference.md](docs/quick-reference.md) |
| Build the full enterprise IT stack | [enterprise-it-101/README.md](enterprise-it-101/README.md) |
| Test what actually stuck (quizzes and written exams) | [assessments/README.md](assessments/README.md) |
| Add a lab | [docs/contributing.md](docs/contributing.md) |
