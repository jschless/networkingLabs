# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

```bash
# Deploy a lab (requires sudo)
sudo containerlab deploy -t labs/<name>/topology.yml
# OR using the helper (no sudo needed — script calls containerlab which handles it):
./scripts/lab.sh deploy <name>

# Destroy a lab
sudo containerlab destroy -t labs/<name>/topology.yml --cleanup
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
  topology.yml          # ContainerLab topology — nodes, links, binds, exec, sysctls
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

All nodes use `kind: linux` with `image: frrouting/frr:latest` (or a custom image). The `defaults:` block in `topology.yml` avoids repetition — `kind`, `image`, `sysctls`, and `exec` can all be set there and inherited by every node.

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

ContainerLab names containers `clab-<topology-name>-<node-name>`. The topology name comes from the `name:` field at the top of `topology.yml`, not the directory name (though they always match here).

### MPLS labs

Labs using MPLS (`mpls-sr-isis-bgp`, `mpls-sr-blank`, `bgp-labeled-unicast`) require:
```yaml
sysctls:
  net.mpls.platform_labels: "1048575"
```
Set via `sysctls:` (not `exec`) so the kernel label space is ready before FRR starts.
