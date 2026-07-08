# SuzieQ Network Observability — Reference Lab

SuzieQ is an agentless network observability tool. It SSHs into your devices,
runs show commands, parses the output into a structured Parquet database, and
then lets you query that data with a unified CLI across your entire fleet at
once. You can ask "show me all interfaces with errors above 0" across all
three routers in a single command, assert that every OSPF session is in Full
state, or trace the forwarding path a packet would take from one loopback to
another — all without touching the routers after the initial poll.

This lab gives you a fully working three-router OSPF network. Your job is to
point SuzieQ at it, collect a snapshot, and work through the main query
types: device discovery, interface state, LLDP neighbor mapping, OSPF health,
routing table analysis, path tracing, and the assert commands that turn the
tool into a continuous health checker.

## Topology

```
               SuzieQ Observer
               172.31.42.100
                    |
  ╔═════════════════╪══════════════════════════════╗
  ║   lab mgmt network  172.31.42.0/24             ║
  ╚════╤══════════════╤═════════════════╤═══════════╝
       │ Mgmt (.11)   │ Mgmt (.12)      │ Mgmt (.13)
  ┌────┴──┐      ┌────┴────┐       ┌────┴──┐
  │  r1   │ Eth1 │   r2    │ Eth2  │  r3   │
  │ OSPF  ├──────┤ OSPF    ├───────┤ OSPF  │
  └───────┘      └─────────┘       └───────┘
  Lo0 10.0.0.1   Lo0 10.0.0.2      Lo0 10.0.0.3
```

### Link addressing

| Link | Subnet | Left side | Right side |
|------|--------|-----------|------------|
| r1:eth1 ↔ r2:eth1 | 10.1.12.0/30 | 10.1.12.1 (r1) | 10.1.12.2 (r2) |
| r2:eth2 ↔ r3:eth1 | 10.1.23.0/30 | 10.1.23.1 (r2) | 10.1.23.2 (r3) |
| mgmt | 172.31.42.0/24 | SuzieQ → .100 | Routers → .11/.12/.13 |

### Node reference

| Node | Kind | Mgmt IP | Role |
|------|------|---------|------|
| r1 | cEOS | 172.31.42.11 | OSPF router, Lo0 10.0.0.1/32 |
| r2 | cEOS | 172.31.42.12 | OSPF transit, Lo0 10.0.0.2/32 |
| r3 | cEOS | 172.31.42.13 | OSPF router, Lo0 10.0.0.3/32 |
| suzieq | Linux | 172.31.42.100 | SuzieQ observer |

All three routers run OSPF Area 0, advertising their loopbacks and
point-to-point links. LLDP is enabled by default on cEOS interfaces.
SuzieQ collects everything by SSHing to the management IPs.

## Deploy

Build the images first (one-time):

```bash
# cEOS (download cEOS-lab-4.35.2F.tar from arista.com, free account required)
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F

# SuzieQ container (installs suzieq from pip, takes a few minutes)
docker build -t suzieq-lab:local labs/suzieq-network-observability/
```

Then deploy:

```bash
./scripts/lab.sh deploy suzieq-network-observability
./scripts/lab.sh status suzieq-network-observability
```

Wait ~30 seconds for cEOS to start SSH before running the poller.

---

## Task 1 — Verify the network before observing it

**Objective:** Confirm all containers are up and the OSPF fabric is healthy.
SuzieQ reports what's there — it won't fix a broken network, so verify first.

```bash
# check all four nodes are running
./scripts/lab.sh status suzieq-network-observability

# verify OSPF neighbors on r2 (the hub; should show both r1 and r3)
./scripts/lab.sh vtysh suzieq-network-observability r2
r2# show ip ospf neighbor

# verify end-to-end reachability
./scripts/lab.sh cmd suzieq-network-observability r1 "ping 10.0.0.3 source 10.0.0.1 repeat 3"
```

<details markdown="1">
<summary>Check your work</summary>

`show ip ospf neighbor` on r2 shows two neighbors — r1 (10.0.0.1) and r3
(10.0.0.3) — both in `Full` state. The ping from r1's loopback to r3's
loopback succeeds. If OSPF is not Full, wait another 20 seconds; cEOS
sometimes takes a moment to load startup-config and bring up routing.

</details>

---

## Task 2 — Run the SuzieQ poller

**Objective:** Shell into the SuzieQ container and poll the network once.
Understand what the poller does and what data lands on disk.

```bash
# open a shell in the SuzieQ container
./scripts/lab.sh bash suzieq-network-observability suzieq
```

Inside the container, the bind-mounted `/workspace` has a pre-configured
inventory file and a config file:

```bash
cat /workspace/inventory.yml    # three cEOS nodes listed by mgmt IP
cat /workspace/suzieq.cfg       # points data-directory at /workspace/parquet-out
```

Run the poller once to collect a snapshot:

```bash
sq-poller -I /workspace/inventory.yml -o /workspace/parquet-out --run-once
```

<details markdown="1">
<summary>Check your work</summary>

The poller logs one connection attempt per device, then exits. When it
finishes, `/workspace/parquet-out/` contains subdirectories for each service
SuzieQ knows about:

```bash
ls /workspace/parquet-out/
# device/  interfaces/  routes/  ospfNbr/  ospfIf/  lldpNbr/  macs/  ...
```

Each subdirectory has one or more `.parquet` files — columnar binary files.
All `sq` queries read from these files; they never touch the live devices again
until you re-run the poller. That's the key architectural distinction: SuzieQ
separates collection from query.

</details>

---

## Task 3 — Device inventory

**Objective:** Query what SuzieQ discovered about each router.

Inside the suzieq container:

```bash
sq --data-directory /workspace/parquet-out device show --namespace fabric
```

**Predict first:** which fields come from your `inventory.yml`, and which are
discovered by querying the device itself?

<details markdown="1">
<summary>Check your work</summary>

The `address` column comes from your inventory file. Everything else —
`hostname`, `vendor`, `os`, `version`, `model`, `serialNumber` — is discovered
by SuzieQ running `show version` over SSH. This matters in production: the
address you *think* something is at and what the device *says it is* are
different kinds of truth, and SuzieQ collects both.

</details>

---

## Task 4 — Interface state across the fleet

**Objective:** Query all interfaces on all three routers with a single command.
Explore the filter options.

```bash
# every interface on every device
sq --data-directory /workspace/parquet-out interface show --namespace fabric

# only r2 (the device with two links)
sq --data-directory /workspace/parquet-out interface show --namespace fabric \
   --hostname r2

# filter to routed interfaces only
sq --data-directory /workspace/parquet-out interface show --namespace fabric \
   --type routed

# find any interface with input or output errors
sq --data-directory /workspace/parquet-out interface show --namespace fabric \
   --query "errorsIn > 0 or errorsOut > 0"
```

**Predict first:** how many interfaces will r2 show — and list them before
running the command.

<details markdown="1">
<summary>Check your work</summary>

r2 has at minimum: `Loopback0`, `Ethernet1`, `Ethernet2`, and `Management0`.
SuzieQ discovers all of them, including Management0 — the interface it
connected through. The `--query` filter uses Pandas query syntax, so you can
compose arbitrary boolean expressions across any column SuzieQ exposes.
A clean lab shows no error rows; that `--query` filter becomes your first
line of defense in production when hunting intermittent link flaps.

</details>

---

## Task 5 — LLDP neighbor map

**Objective:** Use LLDP data to reconstruct the physical topology.

```bash
sq --data-directory /workspace/parquet-out lldp show --namespace fabric
```

**Predict first:** how many rows appear, and why is that number different from
the number of physical links?

<details markdown="1">
<summary>Check your work</summary>

Two physical links → four LLDP rows. LLDP is bidirectional: both ends
advertise to each other, so r1 records a neighbor entry for r2, r2 records
entries for both r1 and r3, and r3 records one for r2. SuzieQ shows the
`hostname`, `ifname`, `peerHostname`, and `peerIfname` for each — exactly the
data a topology map needs. This is how SuzieQ's `path show` (Task 8) knows
which physical device is on the other side of each interface.

</details>

---

## Task 6 — OSPF neighbor and interface state

**Objective:** Query OSPF state and understand the two tables SuzieQ exposes.

```bash
# neighbor adjacency table (who is adjacent and in what state)
sq --data-directory /workspace/parquet-out ospf show --namespace fabric \
   --type nbr

# interface table (cost, timers, network type)
sq --data-directory /workspace/parquet-out ospf show --namespace fabric \
   --type if

# filter to just r2 to see both its adjacencies
sq --data-directory /workspace/parquet-out ospf show --namespace fabric \
   --type nbr --hostname r2
```

<details markdown="1">
<summary>Check your work</summary>

The neighbor table (`type nbr`) shows each adjacency: `peerHostname`,
`peerIP`, `state` (`Full`), area, and DR/BDR election result. On cEOS with
default OSPF settings, point-to-point links elect no DR — you'll see
`0.0.0.0` in the DR column, which is correct for `pointToPoint` network type.

The interface table (`type if`) shows `cost`, `nbrCount`, `deadInterval`,
`helloInterval`, and `networkType`. r2 has two OSPF interfaces (Ethernet1 and
Ethernet2) and its Loopback0 listed as passive.

</details>

---

## Task 7 — Routing table analysis

**Objective:** Query the routing table across all devices. Answer a fleet-wide
question that would normally require three separate `show ip route` sessions.

```bash
# complete routing table across all three routers
sq --data-directory /workspace/parquet-out route show --namespace fabric

# only OSPF-learned routes
sq --data-directory /workspace/parquet-out route show --namespace fabric \
   --protocol ospf

# find a specific prefix on every device that has it
sq --data-directory /workspace/parquet-out route show --namespace fabric \
   --prefix 10.0.0.3/32
```

**Predict first:** how many OSPF routes should r1 have, and what are they?
List them before running the command.

<details markdown="1">
<summary>Check your work</summary>

r1 should have three OSPF routes:
- `10.0.0.2/32` — r2's loopback, direct OSPF neighbor
- `10.0.0.3/32` — r3's loopback, via r2
- `10.1.23.0/30` — the r2↔r3 link, via r2

The query for `10.0.0.3/32` shows that prefix on all three routers at once:
r1 and r2 have it as an OSPF route, r3 has it as a connected route. Getting
that cross-device view without SuzieQ requires logging into each box and
checking individually — a three-router lab is manageable, but the same
workflow applied to a 200-device network is not.

</details>

---

## Task 8 — Path tracing

**Objective:** Trace the forwarding path between two loopbacks using SuzieQ's
`path show` command. SuzieQ builds the path entirely from its collected data —
no live device queries.

```bash
# forward path: r1 loopback → r3 loopback
sq --data-directory /workspace/parquet-out path show --namespace fabric \
   --src 10.0.0.1 --dest 10.0.0.3

# reverse path: r3 → r1
sq --data-directory /workspace/parquet-out path show --namespace fabric \
   --src 10.0.0.3 --dest 10.0.0.1
```

**Predict first:** which hops and which interfaces will appear in the
r1→r3 path?

<details markdown="1">
<summary>Check your work</summary>

The path shows: **r1** (egress via Ethernet1) → **r2** (ingress via Ethernet1,
egress via Ethernet2) → **r3** (ingress via Ethernet1). SuzieQ derives this by
chaining routing table lookups (which interface has the next-hop?) with LLDP
data (which device is physically on the other end of that interface?). The
forward and reverse paths are symmetric in this simple topology. In production
networks with asymmetric policy routing or traffic engineering they often
differ — and SuzieQ will show you both independently.

</details>

---

## Task 9 — Health assertions

**Objective:** Run SuzieQ's `assert` commands to validate network health.
Assertions encode invariants and produce a pass/fail output suitable for CI.

```bash
# assert all OSPF adjacencies are healthy
sq --data-directory /workspace/parquet-out ospf assert --namespace fabric

# assert interface health (admin state, error counters, MTU)
sq --data-directory /workspace/parquet-out interface assert --namespace fabric

# assert routing table consistency
sq --data-directory /workspace/parquet-out route assert --namespace fabric
```

Now break something deliberately to see what a failure looks like:

```bash
# on your host terminal, shut Ethernet1 on r1
./scripts/lab.sh vtysh suzieq-network-observability r1
```

```
r1# configure
r1(config)# interface Ethernet1
r1(config-if)# shutdown
r1(config-if)# end
```

Back in the suzieq container, re-poll and re-assert:

```bash
sq-poller -I /workspace/inventory.yml -o /workspace/parquet-out --run-once

sq --data-directory /workspace/parquet-out ospf assert --namespace fabric
sq --data-directory /workspace/parquet-out interface assert --namespace fabric
```

<details markdown="1">
<summary>Check your work</summary>

With `Ethernet1` shut on r1, `ospf assert` shows a FAIL row for r1 (lost
its only OSPF neighbor) and `interface assert` fails on r1:Ethernet1
(admin-down). The assertions identify the specific device and interface, not
just "something is wrong". This is the difference between using SuzieQ as a
query tool and using it as a health-check in a pipeline: `sq assert` exits
non-zero on any failure, so `if sq ... assert; then deploy; fi` is a real
workflow.

Restore the interface when done:

```bash
./scripts/lab.sh vtysh suzieq-network-observability r1
```
```
r1# configure
r1(config)# interface Ethernet1
r1(config-if)# no shutdown
r1(config-if)# end
```

</details>

---

## Task 10 — Continuous polling (optional)

**Objective:** Run the poller in daemon mode and watch the database update as
the network changes.

Inside the suzieq container:

```bash
# start the poller as a background daemon (polls every 15 s per suzieq.cfg)
sq-poller -I /workspace/inventory.yml -o /workspace/parquet-out &
POLLER_PID=$!

# in another terminal, add a loopback to r2
./scripts/lab.sh vtysh suzieq-network-observability r2
```
```
r2# configure
r2(config)# interface Loopback1
r2(config-if)# ip address 192.168.100.2/32
r2(config-if)# end
```

```bash
# wait ~15 seconds, then query for the new interface
sq --data-directory /workspace/parquet-out interface show --namespace fabric \
   --hostname r2 --ifname Loopback1

# kill the poller when done
kill $POLLER_PID
```

<details markdown="1">
<summary>Check your work</summary>

After one polling cycle (up to 15 seconds), `Loopback1` appears in SuzieQ's
interface table for r2 with status `up`. The parquet directory now contains
files from both the first snapshot and the second poll. Remove the loopback
on r2 and re-poll to confirm it disappears from SuzieQ's view.

</details>

---

## Verification

Run these from the suzieq container after a clean poll:

```bash
# poll first
sq-poller -I /workspace/inventory.yml -o /workspace/parquet-out --run-once

# three devices discovered
sq --data-directory /workspace/parquet-out device show --namespace fabric

# two OSPF neighbors on r2
sq --data-directory /workspace/parquet-out ospf show --namespace fabric \
   --type nbr --hostname r2

# no assertion failures
sq --data-directory /workspace/parquet-out ospf assert --namespace fabric
sq --data-directory /workspace/parquet-out interface assert --namespace fabric
```

Manual checklist:

- [ ] All four containers up (`./scripts/lab.sh status suzieq-network-observability`)
- [ ] OSPF Full on r2 (`show ip ospf neighbor` shows both r1 and r3)
- [ ] `sq device show` returns r1, r2, r3
- [ ] `sq path show --src 10.0.0.1 --dest 10.0.0.3` traces through r2
- [ ] `sq ospf assert` exits clean (no FAIL rows)

---

## Challenge questions

No answers provided — reason through them from what you observed.

1. SuzieQ writes a new snapshot each poll cycle. If a device is unreachable
   mid-poll — say, Management0 goes down on r2 — does SuzieQ report stale
   data, empty data, or an error row? Try it: shut Management0 on r2 and
   re-poll, then query `sq device show`.
2. `sq path show` requires both routing table data and LLDP data. What happens
   if LLDP is disabled on a router — and what does this imply for operators
   who disable LLDP "for security"?
3. The `assert` commands exit non-zero on failures. Sketch a CI/CD pipeline
   step that runs `sq ospf assert` after a maintenance change and blocks
   rollout if any adjacency is lost. What two things would you need to be sure
   of before trusting that gate in production?
4. SuzieQ stores all data as Parquet files. How would you answer "which
   interface crossed 1000 input errors in the last hour" — does the current
   lab data support that query, and if not, what would you need to add?
5. This lab has three routers and no BGP. Add a fourth cEOS node running eBGP
   toward r1, rebuild the inventory, and run `sq bgp assert`. What assertions
   does SuzieQ make about BGP by default, and are any of them wrong for a
   legitimate but unusual BGP design?

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `sq-poller: command not found` | Image not built or wrong container | `docker build -t suzieq-lab:local labs/suzieq-network-observability/`; confirm you're inside the `suzieq` container |
| `Connection refused` to routers | cEOS SSH not ready yet | Wait 30–60 s after deploy; cEOS takes a moment to start SSH after loading startup-config |
| `Authentication failed` | Username/password mismatch | Confirm `admin`/`admin` in startup-configs; test manually: `ssh admin@172.31.42.11` from inside the container |
| `No data` in `sq` queries | Poller hasn't run | Run `sq-poller ... --run-once` first; all `sq` commands read from the parquet cache |
| `ospf assert` FAIL with `iftype` | SuzieQ strict network-type check on EOS p2p links | Informational — EOS reports the OSPF network type differently than SuzieQ expects; not a real fault |
| `path show` returns no hops | LLDP data missing or prefix not in RIB | Confirm `sq lldp show` returns neighbors; ensure src/dest are loopback IPs that appear in `sq route show` |
| Parquet directory empty after poll | Wrong output path | Confirm `-o /workspace/parquet-out` in the poller command; check `ls /workspace/` |
| Router config lost after redeploy | containerlab resets to startup-config | Expected — re-run the poller after each redeploy |
