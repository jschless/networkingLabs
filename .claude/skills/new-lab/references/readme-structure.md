# README Structure Patterns

## Practice Lab README

```markdown
# <Protocol/Feature> — Practice Lab

<1-2 sentence description of what the user will build.>

---

## Topology

```
[ascii diagram of nodes and links]
```

### Link addressing

| Link      | Subnet        | Left side       | Right side      | Notes   |
|-----------|---------------|-----------------|-----------------|---------|
| r1 — r2   | 10.1.12.0/30  | 10.1.12.1 (r1)  | 10.1.12.2 (r2)  |         |

### Node reference

| Node | Loopback     | Role                  | AS / Area |
|------|--------------|----------------------|-----------|
| r1   | 10.0.0.1/32  | <role description>   |           |

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/<name>/topology.yml

# Open CLI on any node
docker exec -it clab-<name>-r1 Cli

# Or use helper
./scripts/lab.sh Cli <name> r1
```

---

## Step 1 — <first task>

<explanation>

### r1

```
<config commands>
```

### r2

```
<config commands>
```

---

## Step 2 — <next task>

...

---

## Verification

```
<show commands with expected output descriptions>
```

---

## Experiments

### <optional extension 1>

<description and commands>

---

## Troubleshooting

**<symptom>**
- <cause and fix>

**<symptom>**
- <cause and fix>
```

---

## Debug Lab README

```markdown
# <lab-name> — Broken <Protocol>

<Narrative: colleague configured it, passed initial testing, "someone made a small change", now broken. Do not look at configs — diagnose from symptoms.>

Your job: deploy the lab, use show commands to find the fault, and fix it.
**Do not look at the config files yet** — diagnose from symptoms first.

---

## Topology

```
[same ascii diagram as reference lab]
```

### Link addressing

| Link      | Subnet        | r-left           | r-right          | Correct area/AS |
|-----------|---------------|------------------|------------------|-----------------|

### Node reference

| Node | Loopback    | Role           | Correct config  |
|------|-------------|----------------|-----------------|

---

## Expected behavior (when healthy)

- <bullet 1: specific reachability or adjacency that should work>
- <bullet 2>
- <bullet 3>

---

## Deploy and access

```bash
sudo containerlab deploy -t labs/<name>/topology.yml

docker exec -it clab-<name>-r1 Cli
./scripts/lab.sh Cli <name> r1
```

Wait ~15 seconds after deploy for <protocol> to attempt convergence.

---

## Symptoms

- <specific failure symptom 1>
- <specific failure symptom 2>

Start here:
```
<first diagnostic command>
```

---

## Hints

<details>
<summary>Hint 1 — Where to look</summary>

<which node or interface or protocol area to investigate>

</details>

<details>
<summary>Hint 2 — What command to run</summary>

```
<specific show command that reveals the problem>
```

</details>

<details>
<summary>Hint 3 — What you will see</summary>

<describe the specific wrong value or missing config that appears>

</details>

---

## Solution

<details>
<summary>Solution — reveal only after attempting the lab</summary>

**Bug**: <one sentence description of the bug>

**Affected node**: <node name>

**Fix**:
```
<exact config commands to fix it>
```

**Why it broke**: <explanation of why this caused the observed symptoms>

</details>
```

---

## Common Verification Commands (cEOS)

| What to check | Command |
|---------------|---------|
| OSPF neighbors | `show ip ospf neighbor` |
| OSPF routes | `show ip route ospf` |
| BGP summary | `show bgp summary` |
| BGP routes | `show bgp` |
| IS-IS neighbors | `show isis neighbors` |
| IS-IS routes | `show ip route isis` |
| Interface status | `show interface status` |
| VXLAN VTEPs | `show vxlan vtep` |
| EVPN routes | `show bgp evpn` |
| VRF routing | `show ip route vrf <name>` |
| BFD sessions | `show bfd peers` |
