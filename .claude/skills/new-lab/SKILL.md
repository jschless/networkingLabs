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
- **Lab type**: almost always **practice** (IPs pre-configured, user implements the protocol). Use **reference** if they said "show me a working example". Use **debug** if they said "I want to troubleshoot" or "find the bug".
- **Platform**: default to **cEOS** unless they asked for SR-Linux specifically or the feature requires it

If anything critical is ambiguous, ask one focused question before building. Do not ask about things you can reasonably decide (topology size, IP ranges, node names).

### 2. Choose a Topology

Pick the simplest topology that meaningfully demonstrates the feature. See [references/topology-patterns.md](references/topology-patterns.md).

Assign IP addressing:
- Point-to-point links: `/30` subnets — `10.1.12.0/30` for r1↔r2, `10.1.23.0/30` for r2↔r3, etc.
- Loopbacks: `10.0.0.N/32` where N matches the router number
- Comment every link in `topology.yml` with its subnet

### 3. Choose a Platform

**Priority order — use the first one that fits:**

1. **cEOS** (`kind: ceos`, image `ceos:4.35.2F`) — default for everything. EOS CLI, industry-standard syntax, no setup scripts needed.
2. **SR-Linux** (`kind: srl`, image `ghcr.io/nokia/srlinux:latest`) — use only when the lab specifically targets SR-Linux or is a parallel NOS version of an existing cEOS lab.
3. **FRR** (`kind: linux`, image `frrouting/frr:latest`) — last resort. Use only for simulating end-user host devices (minimal Linux + IP stack), or a protocol that is FRR-only. Never use FRR as a routing platform when cEOS can do the same thing.

### 4. Create All Files

Create the complete directory structure and every file. Do not stop at topology.yml — build everything before presenting results.

```
labs/<lab-name>/
  topology.yml
  README.md
  configs/
    <node>/
      startup-config     (cEOS)
      config.cli         (SR-Linux)
      frr.conf + daemons (FRR routing node)
```

Refer to the reference files for correct syntax:
- [references/ceos-patterns.md](references/ceos-patterns.md)
- [references/srlinux-patterns.md](references/srlinux-patterns.md)
- [references/frr-patterns.md](references/frr-patterns.md)
- [references/readme-structure.md](references/readme-structure.md)

---

## topology.yml Templates

### cEOS

```yaml
name: <lab-name>

topology:
  nodes:
    r1:
      kind: ceos
      image: ceos:4.35.2F
      startup-config: configs/r1/startup-config

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

### FRR (host/last-resort only)

```yaml
name: <lab-name>

topology:
  defaults:
    kind: linux
    image: frrouting/frr:latest

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
3. Use `startup-config:` key in topology.yml — NOT `binds:`
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

---

## Completeness Checklist

Before finishing, verify:
- [ ] `topology.yml` `name:` field matches `labs/<lab-name>/` directory name exactly
- [ ] Every link in topology.yml has a subnet comment
- [ ] Every cEOS startup-config has `ip routing` and `no switchport` on all routed Ethernet interfaces
- [ ] Practice lab: IPs and hostnames set, routing config absent but hinted
- [ ] Debug lab: exactly ONE bug in exactly ONE node; all others are fully correct working configs
- [ ] README has: topology ASCII diagram, link table, node table, deploy commands, numbered steps, verification commands, troubleshooting section
