# How It Works

## Lab Anatomy

```
labs/<name>/
  topology.clab.yml          # ContainerLab topology — nodes, links, binds, exec, sysctls
  README.md                  # Lab guide: tasks and verification commands
  configs/
    daemons                  # Which FRR daemons to enable (shared across nodes)
    vtysh.conf               # Always "service integrated-vtysh-config" (shared)
    <node>/
      frr.conf               # FRR routing config for this node
      startup-config         # cEOS EOS startup config
      config.boot            # VyOS startup config
      setup.sh               # (some nodes) Linux network setup script
```

## Two Lab Types

**Practice labs** — IP addressing is pre-configured. You implement the routing protocol or feature using `vtysh` (FRR), `Cli` (cEOS), or VyOS configure mode. Each config file contains commented hints showing the expected configuration.

**Reference labs** — Fully working out of the box. Deploy and observe or explore.

Practice lab README convention (the full contract is `labs/AUTHORING.md`):

- every task states an **objective** the student attempts first; **hints**,
  the **solution**, and a **check your work** explanation are each hidden in
  their own `<details>` toggle
- prediction prompts and verification stay visible; raw configuration is
  never shown in the open
- debug labs hide the exact fix in a solution block rather than exposing it inline

## Startup Sequence

When ContainerLab deploys a topology:

1. Containers start with `kind: linux` (or `ceos` / `srl` / `vyosnetworks_vyos`)
2. `sysctls:` are applied **before** the container process starts — used for `net.mpls.platform_labels`
3. veth pairs connecting nodes are created
4. `exec:` commands run **after** interfaces exist — always includes `vtysh -b` to reload FRR config

This ordering matters: FRR starts before veth pairs exist, so `vtysh -b` is required to re-apply interface-level config (OSPF area, MPLS enable, etc.) after the interfaces appear.

## FRR Node Pattern

```yaml
defaults:
  kind: linux
  image: frr-lab:local
  sysctls:
    net.ipv4.ip_forward: "1"
  exec:
    - vtysh -b

nodes:
  r1:
    binds:
      - configs/daemons:/etc/frr/daemons
      - configs/vtysh.conf:/etc/frr/vtysh.conf
      - configs/r1/frr.conf:/etc/frr/frr.conf
```

## cEOS Node Pattern

```yaml
nodes:
  leaf1:
    kind: ceos
    image: ceos:4.35.2F
    startup-config: configs/leaf1/startup-config
```

ContainerLab handles environment variables, management interface, and EOS startup automatically. No `binds:` needed for cEOS config.

## VyOS Node Pattern

```yaml
nodes:
  hub:
    kind: vyosnetworks_vyos
    image: vyos:local
    startup-config: configs/hub/config.boot
```

VyOS labs use router-image startup configuration via `config.boot`. Operational commands can be run through the admin shell or via `vbash` for non-interactive checks.

## When to Use setup.sh

Use a bind-mounted `setup.sh` (called via `exec: - bash /setup.sh`) when a node needs Linux commands before FRR starts: creating VRFs (`ip link add … type vrf`), VXLAN+bridge interfaces, or non-FRR IP assignment. The script ends with `vtysh -b` to load FRR config after Linux setup completes.

## Choosing FRR vs Router Images

Prefer a router image when the local image has been validated to support the exact lab behavior and the node count is reasonable for the host.

Keep FRR when:

- the router image does not support the feature in the local container build
- the lab depends on Linux-first mechanics that are not a clean fit for the router OS
- the topology is large enough that router-image RAM cost is not worth it

Use a live image probe before rebuilds. Documentation alone is not enough because containerized router images often expose only a subset of the full platform feature set.

## Container Naming

ContainerLab names containers `clab-<topology-name>-<node-name>`. The topology name comes from the `name:` field at the top of `topology.clab.yml`.

```bash
# topology name: ospf-multiarea, node: r1
docker exec -it clab-ospf-multiarea-r1 vtysh
```
