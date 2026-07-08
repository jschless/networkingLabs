# NetBox Automation Capstone Lab

This lab is a source-of-truth capstone built around NetBox.

You will use NetBox for:

- DCIM objects: site, racks, manufacturer, platform, roles, devices, interfaces, cables
- IPAM objects: prefixes, IP addresses, primary IPs, VLANs, VRFs
- config context and native config templates
- rendered configuration output through the live NetBox API
- reconciliation between live device facts and the modeled state

The automation node includes scripts and playbooks to:

- seed NetBox
- render EOS configs from NetBox's native `render-config` endpoint
- push rendered configs
- back up running configs
- gather live facts
- sync discovered facts back into NetBox
- detect drift between NetBox and live devices

## Build

```bash
docker build -t netbox-automation:local labs/network-automation-netbox/
./scripts/lab.sh deploy network-automation-netbox
```

## Access

- NetBox UI: `http://127.0.0.1:8001`
- NetBox login: `admin` / `admin`
- automation shell:

```bash
./scripts/lab.sh bash network-automation-netbox automation
```

If you are on a different machine than the lab host, forward the UI with SSH:

```bash
ssh -N -L 8001:127.0.0.1:8001 <user>@<lab-host>
```

Then browse to `http://127.0.0.1:8001`.

## How to use this lab

This is a **practice lab**, not a tutorial. The environment is pre-built;
you produce the configuration or the diagnosis from the objectives.
**Predict each result before you verify**, and treat the challenge
questions as the real test.

## Topology

```mermaid
flowchart TB
    spine1["spine1\nAS65100\nLo0 10.255.0.11/32\nMgmt 172.31.40.11"]
    spine2["spine2\nAS65101\nLo0 10.255.0.12/32\nMgmt 172.31.40.12"]
    leaf1["leaf1\nAS65111\nLo0 10.255.0.13/32\nMgmt 172.31.40.13"]
    leaf2["leaf2\nAS65112\nLo0 10.255.0.14/32\nMgmt 172.31.40.14"]
    netbox(["netbox\nUI :8001\n172.31.40.23"])
    automation(["automation\nAnsible + Python\n172.31.40.24"])

    spine1 ---|"10.0.0.0/31"| leaf1
    spine1 ---|"10.0.0.2/31"| leaf2
    spine2 ---|"10.0.0.4/31"| leaf1
    spine2 ---|"10.0.0.6/31"| leaf2

    automation -. API .- netbox
    automation -. mgmt .- spine1
    automation -. mgmt .- spine2
    automation -. mgmt .- leaf1
    automation -. mgmt .- leaf2
```

## What Is In The Lab

Routers:

- `spine1`, `spine2`
- `leaf1`, `leaf2`

Service containers:

- `netbox`
- `postgres`
- `redis`
- `automation`

Automation workspace files in `/workspace`:

- `netbox_model.yml`
- `netbox_common.py`
- `eos_device_config.j2`
- `seed_netbox.py`
- `render_from_netbox.py`
- `discover_sync.py`
- `deploy.yml`
- `backup.yml`
- `facts.yml`
- `drift_report.py`
- `inventory.yml`

## What NetBox Will Model

This capstone intentionally uses more of NetBox than the original small lab.

Seeded object types:

- site
- tenant
- manufacturer
- platform
- device type
- device roles
- racks
- tags
- devices
- interfaces
- cables
- VLAN group
- VLANs
- VRFs
- prefixes
- IP addresses
- primary IPs
- config contexts
- config templates

## Lab Addressing

### Management

| Device | Management |
|--------|------------|
| `spine1` | `172.31.40.11/24` |
| `spine2` | `172.31.40.12/24` |
| `leaf1`  | `172.31.40.13/24` |
| `leaf2`  | `172.31.40.14/24` |

### Loopbacks

| Device | Loopback0 |
|--------|-----------|
| `spine1` | `10.255.0.11/32` |
| `spine2` | `10.255.0.12/32` |
| `leaf1`  | `10.255.0.13/32` |
| `leaf2`  | `10.255.0.14/32` |

### Fabric Links

| Link | Subnet |
|------|--------|
| `spine1:Ethernet1` ↔ `leaf1:Ethernet1` | `10.0.0.0/31` |
| `spine1:Ethernet2` ↔ `leaf2:Ethernet1` | `10.0.0.2/31` |
| `spine2:Ethernet1` ↔ `leaf1:Ethernet2` | `10.0.0.4/31` |
| `spine2:Ethernet2` ↔ `leaf2:Ethernet2` | `10.0.0.6/31` |

### Service Objects To Model In NetBox

| Object | Values |
|--------|--------|
| VRFs | `BLUE`, `GREEN` |
| VLANs | `10 USERS`, `20 SERVERS` |
| Service prefixes | `10.10.10.0/24`, `10.20.20.0/24` |

## Step 1 — Verify The Base Fabric

This lab ships with a working underlay so the automation workflow has a known-good starting point.

Run:

```bash
./scripts/lab.sh check network-automation-netbox
```

Expected:

- all BGP adjacencies are established
- loopback reachability works across the fabric
- the NetBox UI responds

## Step 2 — Export NetBox Connection Info

The Python scripts use the NetBox API.

By default they can auto-provision a token using the lab credentials `admin` / `admin`, so this is enough on the automation node:

```bash
./scripts/lab.sh bash network-automation-netbox automation
cd /workspace
export NETBOX_URL=http://172.31.40.23:8080
export NETBOX_USERNAME=admin
export NETBOX_PASSWORD=admin
```

If you prefer a manually created token, set `NETBOX_TOKEN` instead.

## Step 3 — Seed NetBox

The seed model lives in `netbox_model.yml`.

Run:

```bash
cd /workspace
python3 seed_netbox.py
```

This seeds:

- the fabric inventory and rack placement
- management, loopback, and transit addressing
- VLANs, VRFs, and IPAM prefixes
- cable relationships
- a site-scoped config context with automation defaults
- a native NetBox config template for EOS devices

After seeding, explore these NetBox areas:

- `DCIM -> Devices`
- `DCIM -> Interfaces`
- `DCIM -> Cables`
- `IPAM -> Prefixes`
- `IPAM -> IP Addresses`
- `IPAM -> VLANs`
- `IPAM -> VRFs`
- `Organization -> Racks`
- `Extras -> Config Contexts`
- `Extras -> Config Templates`

## Step 4 — Render Configs Through NetBox

Render fresh configs from the live NetBox API:

```bash
cd /workspace
python3 render_from_netbox.py
ls generated/
```

You should get:

- `generated/spine1.cfg`
- `generated/spine2.cfg`
- `generated/leaf1.cfg`
- `generated/leaf2.cfg`

What this script does:

- reads devices, interfaces, IP assignments, VLANs, VRFs, and cable-derived topology from NetBox
- builds per-device context for neighbors and service interfaces
- calls each device's native `/render-config/` API endpoint
- writes the rendered config text to `generated/`

This is the important shift from the old lab: configs are no longer rendered by a local-only Jinja path pretending to be NetBox. NetBox now owns the template and does the rendering.

## Step 5 — Push The Rendered Config

Install collections if needed:

```bash
cd /workspace
ansible-galaxy collection install arista.eos ansible.netcommon
```

Push the rendered config:

```bash
ansible-playbook -i inventory.yml deploy.yml
```

This lets you treat NetBox plus the render step as the intended-state source for the devices.

## Step 6 — Back Up Running Config

```bash
cd /workspace
mkdir -p backups facts
ansible-playbook -i inventory.yml backup.yml
```

This saves current running configs into `backups/`.

## Step 7 — Gather Facts

```bash
cd /workspace
ansible-playbook -i inventory.yml facts.yml
```

This saves EOS facts into `facts/`.

## Step 8 — Sync Discovery Back Into NetBox

NetBox is not a discovery engine by itself. The common pattern is:

- collect live state with something else
- transform it
- reconcile it into NetBox

This lab demonstrates that pattern with gathered EOS facts:

```bash
cd /workspace
python3 discover_sync.py
```

The discovery sync updates selected NetBox fields from live device facts, including:

- device serial numbers
- interface descriptions
- interface MTU
- interface MAC addresses
- interface/IP objects if a discovered interface is missing from NetBox

This is intentionally conservative. It shows how external discovery can feed NetBox without turning the lab into a full NMS.

## Step 9 — Run Drift Detection

```bash
cd /workspace
python3 drift_report.py
```

The drift report now compares NetBox against live facts, not against the original seed YAML.

It checks:

- device serial numbers
- interface/IP consistency
- interface descriptions

This gives you a practical model for comparing:

- source of truth
- intended config
- observed running state

## Step 10 — Introduce Drift And Reconcile It

Make a manual change on one leaf. Good examples:

- change an interface description
- remove a loopback address
- alter a fabric IP

Then rerun:

```bash
ansible-playbook -i inventory.yml facts.yml
python3 drift_report.py
python3 discover_sync.py
python3 drift_report.py
```

Compare:

- `generated/*.cfg`
- `backups/*.cfg`
- `facts/*.json`
- the NetBox UI

The workflow should make the distinction clear:

- `render_from_netbox.py` shows intended state coming out of NetBox
- `facts.yml` shows observed device state
- `discover_sync.py` is the reconciliation step that updates NetBox from live state
- `drift_report.py` tells you whether those datasets still agree

## NetBox Features This Capstone Exercises

### DCIM

- device roles
- device types
- platforms
- racks
- device inventory
- interfaces
- cables
- tags

### IPAM

- prefixes
- IP addresses
- primary IPs
- VLANs
- VRFs

### Extras

- config contexts
- config templates
- native rendered config output via the NetBox API

### Automation

- API-driven data access
- rendered config generation
- programmatic config deployment
- live facts collection
- external discovery feeding NetBox
- drift detection against the source of truth

## Files To Inspect

- `automation/netbox_model.yml`
- `automation/eos_device_config.j2`
- `automation/netbox_common.py`
- `automation/seed_netbox.py`
- `automation/render_from_netbox.py`
- `automation/discover_sync.py`
- `automation/drift_report.py`
- `automation/deploy.yml`
- `configs/spine1/startup-config`
- `configs/spine2/startup-config`
- `configs/leaf1/startup-config`
- `configs/leaf2/startup-config`

## What This Capstone Teaches

- NetBox is most useful as a source of truth, not as a built-in discovery engine
- config templates become more valuable when they render from real NetBox objects and context
- source of truth, intended config, and running state are different datasets
- external discovery plus reconciliation is a normal NetBox operating model
- a small fabric is enough to practice a real automation workflow end to end

## Challenge questions

No answers provided — reason them through.

1. NetBox is a "source of truth." Explain the difference between
   intended state (NetBox) and actual state (the devices), and the two
   directions of drift that automation must reconcile.
2. Modeling IPAM/DCIM in NetBox before pushing config — what class of
   outage (overlapping subnets, duplicate IPs, wrong VLANs) does
   source-of-truth-first prevent?
3. Generating device config from NetBox data (templating): where does a
   bad template or bad data do the *most* damage, and what guardrails
   (dry-run, diff, CI) limit it?
4. When should the network be reconciled *to* NetBox vs. NetBox updated *to*
   the network? Give a case for each and the danger of always trusting one.

## Extensions

These are optional follow-on ideas to deepen the lab. They are not part of the validated base workflow.

- Add an intended-state validation step before deployment so bad NetBox data is caught before configs are pushed.
- Introduce drift on one leaf, then use the discovery and report tooling to decide whether NetBox or the device should win.
- Extend the model with device-role-specific branching so spines and leafs render from a more opinionated source of truth.
- Add a remediation workflow that takes a drift report and automatically proposes or applies the corrective change.
