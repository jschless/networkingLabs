# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Deploy a lab (requires sudo)
sudo containerlab deploy -t labs/<name>/topology.clab.yml
# OR using the helper (no sudo needed — script calls containerlab which handles it):
./scripts/lab.sh deploy <name>

# Destroy a lab
sudo containerlab destroy -t labs/<name>/topology.clab.yml --cleanup
./scripts/lab.sh destroy <name>

# List running nodes and IPs
./scripts/lab.sh list <name>

# Open FRR CLI on a node
docker exec -it clab-<name>-<node> vtysh
./scripts/lab.sh vtysh <name> <node>

# Open a shell on a node
docker exec -it clab-<name>-<node> bash
./scripts/lab.sh bash <name> <node>

# Run a one-off command on a node
./scripts/lab.sh cmd <name> <node> <command>
```

### Custom image builds (required before deploying any lab)

`frr-lab:local` (`docker build -t frr-lab:local images/frr/`) is the base for most FRR/Linux
labs. Every other image and exactly which labs need it is documented in one authoritative
table — **`docs/getting-started.md` → "Images you build"**. Don't re-list image→lab mappings
here; each lab's `topology.clab.yml` is the ground truth, and the getting-started table is
generated from it.

## Architecture

Lab anatomy (directory layout, `configs/` structure), the two lab types, the
FRR/cEOS/VyOS node patterns, the deploy/startup sequence (why `vtysh -b` is required),
`setup.sh` vs inline `exec`, and container naming (`clab-<topology-name>-<node-name>`,
from the `name:` field) are all documented in **`docs/how-it-works.md`** — read that first.

The repo-specific gotchas that aren't obvious from the topology files:

### FRR version and syntax

FRR 8.4 (`frrouting/frr:latest`, which upstream froze at 8.4 in Nov 2022;
`images/frr/Dockerfile` pins it by digest). Notable syntax:
- IS-IS on interface: `ip router isis CORE` (not `isis enable`)
- BGP VPNv4 AF: `address-family ipv4 vpn` (not `address-family vpnv4`)
- eBGP requires policy by default — add `no bgp ebgp-requires-policy` to each BGP instance
- MPLS on interface: `mpls enable`

### MPLS labs

Labs using MPLS (`mpls-sr-isis-bgp`, `mpls-sr-blank`, `bgp-labeled-unicast`) require:
```yaml
sysctls:
  net.mpls.platform_labels: "1048575"
```
Set via `sysctls:` (not `exec`) so the kernel label space is ready before FRR starts.

## Enterprise IT 101 (separate ecosystem)

`enterprise-it-101/` is a **different kind of lab** — **Docker Compose**, not ContainerLab,
driven by `enterprise-it-101/eit.sh` (not `scripts/lab.sh`). Don't apply the ContainerLab
patterns above to it. See **`enterprise-it-101/README.md`** for the curriculum, helper
commands (`build` / `up` / `down` / `exec` / …), and deploy steps; **`AUTHORING.md`** and
**`DESIGN.md`** for authoring rules and per-lab scope.

Agent-relevant specifics that aren't obvious from the compose files:
- **Layering**: Labs 01 and 16 are standalone `docker-compose.yml` files (Lab 01 defines the
  `lab-corp` network; Lab 16 pre-bakes the cumulative end-state); Labs 02–15 are
  `docker-compose.override.yml` files layered on `base/docker-compose.yml`.
- **Cumulative state via auto-provision**: each lab re-declares the foundation services it
  needs (dc1, admin-ws) with `AUTO_PROVISION: "true"`, so the Lab 01 foundation (OUs, users,
  groups) is seeded automatically.
- **Namespacing & persistence**: each compose project is `name: eit101-labNN`; volumes
  (`dc1-data`, `admin-ws-home`) survive teardown unless you pass `-v`.
- **Container naming**: fixed role names (`dc1`, `admin-ws`, `dns1`, `mail1`, …), not the
  `clab-<lab>-<node>` scheme — reach them with `docker exec -it <name>`.
- Custom images are built by `enterprise-it-101/eit.sh build`. All 16 labs are built and
  validated.
