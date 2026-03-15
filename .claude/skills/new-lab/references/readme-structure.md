# README Structure Patterns

## Practice Lab README

The README is the primary guide — it's read on the docs page. The intent is:
- **Explanations and parameter tables are always visible** — users can read why and what
- **Actual CLI commands are hidden by default** in `<details>` toggles — users attempt the config themselves first, then reveal if stuck

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
./scripts/lab.sh cli <name> r1
```

---

## Step 1 — <first task>

<Explanation of what to configure and why. Keep this visible — it's the guide.>

### Parameter reference

| Command | Purpose |
|---------|---------|
| `command x` | what it does |

<details>
<summary>Configuration — reveal if stuck</summary>

```bash
./scripts/lab.sh cli <name> r1
```

```
<config commands for r1>
```

```bash
./scripts/lab.sh cli <name> r2
```

```
<config commands for r2>
```

</details>

---

## Step 2 — Verify

<Verification commands are always visible — these are the goal, not the solution.>

```
<show commands>
<expected output>
```

---

## Troubleshooting

**<symptom>**
- <cause and fix>

**<symptom>**
- <cause and fix>
```

### Key rules for `<details>` usage

- Wrap **all node configuration commands** (the actual CLI input) in `<details>`
- Leave **verification/show commands** outside — they're the guide, not the answer
- Leave **parameter explanation tables** outside — they help users understand what to type
- Leave **conceptual explanations** outside — reading is allowed, typing is the challenge
- Use summary text: `<summary>Configuration — reveal if stuck</summary>`
- Include the access command (`./scripts/lab.sh cli ...`) inside the `<details>` block so the whole "how to configure this node" section is self-contained
- Do not make an exception during platform migrations; a VyOS or cEOS rewrite still hides config by default
- If the lab is being migrated to a router image, validate the feature on the actual local image before rebuilding the lab

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
