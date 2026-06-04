---
name: new-lab
description: Use this skill when the user describes a networking concept, protocol, or scenario they want to practice or learn in a lab environment. Triggers on phrases like "I want to practice X", "can you build me a lab for X", "I want to learn how X works", "create a lab where I can experiment with X", "build a lab that demonstrates X", or any request to design and create a new network lab from scratch.
---

# Design and Build a Network Lab

The user has described something they want to practice or learn. Your job is to design a complete, working lab and create all the files — topology, configs, and README — without the user needing to know the internal structure.

## Workflow

### 1. Understand the Request

Read the user's description carefully. Infer:
- **Topic**: what protocol or feature they want to practice
- **Lab type**: almost always **practice** (IPs pre-configured, user implements the protocol). Use **reference** if they said "show me a working example". Use **debug** if they said "I want to troubleshoot" or "find the bug". Use **capstone** if the request combines multiple features into a larger end-to-end scenario.
- **Platform**: default to **cEOS** unless the feature requires another NOS (see platform priority in step 3)

If anything critical is ambiguous, ask one focused question before building. Do not ask about things you can reasonably decide (topology size, IP ranges, node names).

### 2. Choose a Topology

Pick the simplest topology that meaningfully demonstrates the feature. See [references/topology-patterns.md](references/topology-patterns.md).

Assign IP addressing:
- Point-to-point links: `/30` subnets — `10.1.12.0/30` for r1↔r2, `10.1.23.0/30` for r2↔r3, etc.
- Loopbacks: `10.0.0.N/32` where N matches the router number
- Comment every link in `topology.clab.yml` with its subnet

### 3. Choose a Platform

**Priority order — use the first one that fits:**

1. **cEOS** (`kind: ceos`, image `ceos:4.35.2F`) — default for everything. EOS CLI, industry-standard syntax, no setup scripts needed.
2. **VyOS** (`kind: linux`, image `vyos:local`) — use for IPsec/IKE, strongSwan-style VPNs, MACsec, DMVPN phases, FlexVPN, or any lab needing Linux-native security features that cEOS lacks. Requires `docker build -t vyos:local -f Dockerfile.vyos .`.
3. **SR-Linux** (`kind: srl`, image `ghcr.io/nokia/srlinux:latest`) — use only when the lab specifically targets SR-Linux or is a parallel NOS version of an existing cEOS lab.
4. **FRR** (`kind: linux`, image `frr-lab:local`) — use for MPLS SR labs, host/endpoint simulation, or protocols that are FRR-only. Requires `docker build -t frr-lab:local images/frr/` (adds tcpdump, tshark to the base image). Never use FRR as a routing platform when cEOS can do the same thing.

### 4. Create All Files

Create the complete directory structure and every file. Do not stop at topology.clab.yml — build everything before presenting results.

```
labs/<lab-name>/
  topology.clab.yml
  README.md
  configs/
    <node>/
      startup-config     (cEOS)
      config.cli         (SR-Linux)
      frr.conf + daemons (FRR routing node)
    daemons              (FRR — shared across nodes)
    vtysh.conf           (FRR — always "service integrated-vtysh-config")
  Dockerfile             (only if the lab needs a custom image)
```

Refer to the reference files for correct syntax:
- [references/ceos-patterns.md](references/ceos-patterns.md)
- [references/srlinux-patterns.md](references/srlinux-patterns.md)
- [references/frr-patterns.md](references/frr-patterns.md)
- [references/readme-structure.md](references/readme-structure.md)

---

## topology.clab.yml Templates

### cEOS

```yaml
name: <lab-name>

topology:
  defaults:
    kind: ceos
    image: ceos:4.35.2F

  nodes:
    r1:
      startup-config: configs/r1/startup-config
    r2:
      startup-config: configs/r2/startup-config

  links:
    - endpoints: ["r1:eth1", "r2:eth1"]   # 10.1.12.0/30
```

### SR-Linux

```yaml
name: <lab-name>

topology:
  nodes:
    r1:
      kind: srl
      image: ghcr.io/nokia/srlinux:latest
      startup-config: configs/r1/config.cli

  links:
    - endpoints: ["r1:e1-1", "r2:e1-1"]   # e1-N → ethernet-1/N in SR-Linux
```

### VyOS

```yaml
name: <lab-name>

topology:
  defaults:
    kind: linux
    image: vyos:local

  nodes:
    r1:
      binds:
        - configs/r1/config.boot:/opt/vyatta/etc/config/config.boot
    r2:
      binds:
        - configs/r2/config.boot:/opt/vyatta/etc/config/config.boot

  links:
    - endpoints: ["r1:eth1", "r2:eth1"]   # 10.1.12.0/30
```

### FRR

```yaml
name: <lab-name>

topology:
  defaults:
    kind: linux
    image: frr-lab:local

  nodes:
    r1:
      binds:
        - configs/daemons:/etc/frr/daemons
        - configs/vtysh.conf:/etc/frr/vtysh.conf
        - configs/r1/frr.conf:/etc/frr/frr.conf
      exec:
        - vtysh -b
```

---

## cEOS startup-config Rules (enforced without exception)

1. `no switchport` on **every** routed Ethernet interface — cEOS defaults to L2; IP addresses are silently rejected without this
2. `ip routing` at global level — EOS defaults to L2 switching mode; required for any routing
3. Use `startup-config:` key in topology.clab.yml — NOT `binds:`
4. Topology link interface names `eth1`, `eth2` → map to `Ethernet1`, `Ethernet2` in EOS config
5. No `exec: vtysh -b` — EOS loads startup-config automatically

### Practice lab startup-config shape

```
hostname r1
!
! -------------------------------------------------------
! Node: r1  (<role, e.g. "Area 1 router">)
!
! What you need to configure here:
!   - <task 1>
!   - <task 2>
! Hint:
!   <the actual config lines, commented out>
! -------------------------------------------------------
!
no aaa root
!
ip routing
!
interface Loopback0
 ip address 10.0.0.1/32
!
interface Ethernet1
 no switchport
 description to r2
 ip address 10.1.12.1/30
!
```

IPs, descriptions, and hostnames are pre-configured. The routing protocol config is **absent** — only present as `!` comments in the hint block.

Also update the docs metadata for every new lab:
- Add the lab to the appropriate track table in `README.md`
- Add the wrapper page in `docs/tracks/<track>/<lab-name>.md` (see Docs Wrapper Template below)
- Add the matching nav entry in `mkdocs.yml` under that track so the lab shows up in the docs sidebar

### Custom Docker images

If the lab needs packages beyond the base image (e.g., tcpdump, iperf, strongSwan, RADIUS), create a `Dockerfile` inside the lab directory and document the build command in the root `README.md` under "Labs requiring custom images":

```bash
docker build -t <lab-name>-lab:local labs/<lab-name>/
```

Name the image `<descriptive>:local` to match the repo convention.

---

## Completeness Checklist

Before finishing, verify:
- [ ] `topology.clab.yml` `name:` field matches `labs/<lab-name>/` directory name exactly
- [ ] Every link in topology.clab.yml has a subnet comment
- [ ] Every cEOS startup-config has `ip routing` and `no switchport` on all routed Ethernet interfaces
- [ ] FRR labs use `frr-lab:local` image (not `frrouting/frr:latest`)
- [ ] Practice lab: IPs and hostnames set, routing config absent but hinted
- [ ] Debug lab: exactly ONE bug in exactly ONE node; all others are fully correct working configs
- [ ] Capstone lab: multiple features integrated, all configs working, README has architecture overview
- [ ] README has: topology ASCII diagram, link table, node table, deploy commands, numbered steps, verification commands, troubleshooting section
- [ ] README deploy section uses `./scripts/lab.sh cli <name> <node>` (not `vtysh` or `Cli` directly)
- [ ] Docs wrapper page created at `docs/tracks/<track>/<lab-name>.md` with correct template (see below)
- [ ] Nav entry added in `mkdocs.yml` under the correct track
- [ ] If the lab requires a custom Docker image, the build command is documented in the root `README.md` prerequisites

---

## Docs Wrapper Page Template

Create `docs/tracks/<track>/<lab-name>.md` with this exact format:

```markdown
---
title: <lab-name>
---

!!! tip "<Lab Type> Lab"
    <one-line description of the lab>

!!! note "Image" <platform> — `<image pull/build command>`

{%
  include-markdown "../../../labs/<lab-name>/README.md"
%}
```

Lab type admonition values: `Practice Lab`, `Reference Lab`, `Debug Lab`, `Capstone Lab`.

Image note examples:
- cEOS: `Arista cEOS — docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F`
- VyOS: `vyos:local — docker build -t vyos:local -f Dockerfile.vyos .`
- FRR: `frr-lab:local — docker build -t frr-lab:local images/frr/`
- SR-Linux: `ghcr.io/nokia/srlinux:latest — docker pull ghcr.io/nokia/srlinux:latest`

Then add the nav entry in `mkdocs.yml` under the appropriate track section:
```yaml
    - <lab-name>: tracks/<track>/<lab-name>.md
```
