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

```bash
docker build -t frr-lab:local images/frr/             # used by: all FRR labs (adds tcpdump, tshark)
docker build -t ipsec-lab:local labs/ipsec-basics/    # used by: ipsec-basics, gre-ipsec
docker build -t wireguard-lab:local labs/wireguard/   # used by: wireguard
```

## Architecture

### Lab layout

```
labs/<name>/
  topology.clab.yml          # ContainerLab topology — nodes, links, binds, exec, sysctls
  README.md             # Lab guide: tasks and verification commands
  configs/
    daemons             # Which FRR daemons to enable (often shared across all nodes)
    vtysh.conf          # Always "service integrated-vtysh-config" (shared)
    <node>/
      frr.conf          # FRR routing config for this node
      setup.sh          # (some nodes) Linux network setup: VRF creation, VXLAN bridges, IP config
```

### Two lab types

- **Practice labs**: IP addressing pre-configured; routing protocols/features left for the user to implement. `frr.conf` files contain commented hints showing expected config.
- **Reference labs**: Fully working out-of-the-box (`mpls-sr-isis-bgp`, `vxlan-evpn`). Deploy and explore.

### Topology patterns

All nodes use `kind: linux` with `image: frrouting/frr:latest` (or a custom image). The `defaults:` block in `topology.clab.yml` avoids repetition — `kind`, `image`, `sysctls`, and `exec` can all be set there and inherited by every node.

Key topology fields:
- `binds`: bind-mounts host files into the container (FRR configs, setup scripts)
- `sysctls`: kernel parameters set **before** container starts — use this (not `exec`) for `net.mpls.platform_labels`
- `exec`: commands run after container starts; always include `vtysh -b` on FRR nodes to re-apply config after veth pairs are created

### When to use `setup.sh` vs inline `exec`

Use a bind-mounted `setup.sh` (called via `exec: - bash /setup.sh`) when a node needs multiple Linux commands: creating Linux VRFs (`ip link add … type vrf`), building VXLAN+bridge interfaces, or setting IP addresses (non-FRR nodes). The script ends with `vtysh -b` to load FRR config after Linux setup completes.

### FRR version and syntax

FRR 8.4 (`frrouting/frr:latest`). Notable syntax:
- IS-IS on interface: `ip router isis CORE` (not `isis enable`)
- BGP VPNv4 AF: `address-family ipv4 vpn` (not `address-family vpnv4`)
- eBGP requires policy by default — add `no bgp ebgp-requires-policy` to each BGP instance
- MPLS on interface: `mpls enable`

### Container naming

ContainerLab names containers `clab-<topology-name>-<node-name>`. The topology name comes from the `name:` field at the top of `topology.clab.yml`, not the directory name (though they always match here).

### MPLS labs

Labs using MPLS (`mpls-sr-isis-bgp`, `mpls-sr-blank`, `bgp-labeled-unicast`) require:
```yaml
sysctls:
  net.mpls.platform_labels: "1048575"
```
Set via `sysctls:` (not `exec`) so the kernel label space is ready before FRR starts.

## Enterprise IT 101 (separate ecosystem)

The top-level `enterprise-it-101/` directory is a **different kind of lab** and does **not**
use ContainerLab or `scripts/lab.sh`. It teaches enterprise IT services (Active Directory,
PKI, DNS, DHCP, email, SSO, RADIUS) with **Docker Compose**. Don't apply the containerlab
patterns above to it.

Key differences:
- **Orchestration**: Docker Compose, not ContainerLab. Lab 01 ships a standalone
  `docker-compose.yml` (defines its own `lab-corp` network); Labs 02–12 are
  `docker-compose.override.yml` files layered on `base/docker-compose.yml`.
- **Cumulative state**: each lab re-declares the foundation services it needs (dc1, admin-ws)
  with `AUTO_PROVISION: "true"` so the Lab 01 foundation (OUs, users, groups) is seeded
  automatically. Each compose project is namespaced via `name: eit101-labNN`, and persistent
  volumes (`dc1-data`, `admin-ws-home`) survive teardown unless you pass `-v`.
- **Container naming**: fixed role names (`dc1`, `admin-ws`, `dns1`, `mail1`, …), not the
  `clab-<lab>-<node>` scheme — reach them with `docker exec -it <name>`.
- **Custom images** (build once, tagged `<name>:local`):
  ```bash
  for img in samba-ad workstation bind9 kea ansible freeradius-ad squid-ad; do
    docker build -t "$img:local" "enterprise-it-101/images/$img/"
  done
  ```

Use the `enterprise-it-101/eit.sh` helper for everything (`build`, `up <NN>`, `down <NN>`,
`exec <NN> <container>`, `ps`, `logs`, `list`). Deploy by hand from the `enterprise-it-101/`
directory:
```bash
# Lab 01 (standalone)
docker compose -f labs/01-active-directory/docker-compose.yml up -d
# Labs 02–12 (base + override)
docker compose -f base/docker-compose.yml \
  -f labs/05-dns-deep-dive/docker-compose.override.yml up -d
```

Authoring rules and per-lab scope live in `enterprise-it-101/AUTHORING.md` and
`enterprise-it-101/DESIGN.md`. Labs 13–16 (monitoring, SIEM, backup, capstone) are planned,
not yet built.
