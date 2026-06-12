# Network Automation Fundamentals — Practice Lab

You have two routers running eBGP and a Linux container with Python. By the end
of this lab you will have driven the routers entirely through their management
API: pulled structured state, parsed JSON instead of screen-scraping text,
made an **idempotent** configuration change, and verified the change from the
*other* router — the read→change→verify loop that every real automation system
(Ansible, Nornir, vManage, DNA Center) is built on. This is the hands-on
counterpart to the ENCOR automation domain, and the on-ramp to the
`network-automation-netbox` capstone.

The API here is Arista **eAPI** — JSON-RPC over HTTP. The mechanics (HTTP
verbs, status codes, auth, JSON payloads) transfer directly to RESTCONF,
NX-API, and every vendor REST API; the challenge questions push on exactly
where they differ from NETCONF/RESTCONF.

## Topology

```
              automation container
               172.31.41.21  (Python, curl, jq)
                     │
   ╔═════════════════╧══════════════════════╗
   ║   containerlab mgmt network            ║
   ║   172.31.41.0/24                       ║
   ╚════╤═══════════════════════════╤═══════╝
        │ Management0 (.11)         │ Management0 (.12)
   ┌────┴─────┐               ┌─────┴────┐
   │    r1    │ Eth1     Eth1 │    r2    │
   │ AS 65001 ├───────────────┤ AS 65002 │
   └──────────┘  10.1.12.0/30 └──────────┘
   Lo0 10.0.0.1/32            Lo0 10.0.0.2/32
```

| Link | Subnet | Purpose |
|------|--------|---------|
| r1:eth1 ↔ r2:eth1 | 10.1.12.0/30 | eBGP peering (pre-configured) |
| mgmt network | 172.31.41.0/24 | eAPI access from the automation container |

| Node | Kind | Mgmt IP | Role |
|------|------|---------|------|
| r1 | cEOS | 172.31.41.11 | eBGP peer, AS 65001, Lo0 10.0.0.1/32 |
| r2 | cEOS | 172.31.41.12 | eBGP peer, AS 65002, Lo0 10.0.0.2/32 |
| automation | Linux | 172.31.41.21 | Python 3.12, `requests`, `pyyaml`, `pygnmi`, `curl`, `jq` |

Both routers come up with addressing, an `admin`/`admin` user, and a working
eBGP session advertising their loopbacks. **The API is not enabled** — that is
your first job. The lab's `automation/` directory is bind-mounted into the
automation container at `/workspace`, so you can edit scripts on your host
with your normal editor and run them inside the container.

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure.** When a task asks for a prediction,
  commit to an answer before touching the CLI. Being wrong and finding out
  why is the point.
- **Open the hints before the solution.** The solution toggle is the answer
  key — use it to check your work or when genuinely stuck, not as step one.
- **Verify like an operator.** After each task, prove the state is what you
  think it is with `show` commands before moving on.

## Deploy

Build the images first (one-time):

```bash
# cEOS (download cEOS-lab 4.35.2F from arista.com, free account required)
docker import cEOS-lab-4.35.2F.tar ceos:4.35.2F

# the automation container
docker build -t automation-fundamentals:local labs/automation-fundamentals/
```

Then:

```bash
./scripts/lab.sh deploy automation-fundamentals
./scripts/lab.sh status automation-fundamentals
```

## Task 1 — Deploy and get your bearings

**Objective:** Confirm all three containers are up, the automation container
can reach both routers' management IPs, and the pre-configured BGP session is
Established.

This is setup — the commands are given:

```bash
# a shell in the automation container (your seat for the whole lab)
./scripts/lab.sh shell automation-fundamentals automation

# inside it:
cd /workspace
ping -c 2 172.31.41.11
ping -c 2 172.31.41.12

# and on a router, the state you'll soon read via the API:
./scripts/lab.sh cli automation-fundamentals r1
r1# show ip bgp summary
```

<details>
<summary>Check your work</summary>

`show ip bgp summary` on r1 should show peer `10.1.12.2` in state
`Estab` with prefixes received. Both pings succeed. If BGP is not
Established, fix that before automating anything — automation against a
broken network just breaks it faster.

</details>

## Task 2 — Enable the API

**Objective:** Enable eAPI over plain HTTP on **both** routers, so that a
client on the management network can send it commands.

**Predict first:** once enabled, which TCP port will the routers listen on —
and from the automation container, how could you prove the port is open
before sending a single API call?

<details>
<summary>Hints</summary>

- The config tree lives under `management api http-commands` — go there and
  look at `?`.
- The eAPI agent ships disabled (`shutdown`) and HTTPS-only by default. You
  need it `no shutdown` **and** speaking plain `http` for this lab (we deal
  with the security implications in the challenge questions).
- Verify with `show management api http-commands` — read the whole output,
  you will need to recognize it again in Task 7.

</details>

<details>
<summary>Solution</summary>

```text
configure
management api http-commands
   no shutdown
   protocol http
end
```

(on both r1 and r2)

</details>

<details>
<summary>Check your work</summary>

`show management api http-commands` should report the agent **running** and
an HTTP server enabled on **port 80** (HTTPS, if shown, is separate, on 443).
From the automation container, `curl -s http://172.31.41.11/command-api`
should now get an HTTP response (an auth error — 401 — is fine and expected:
the port is open, you just haven't authenticated). That answers the
prediction: eAPI over plain HTTP is just a web server on TCP/80, and anything
that can speak HTTP — curl, Python, your browser — is now a network
management tool.

</details>

## Task 3 — Speak the protocol raw, once

**Objective:** From the automation container, run `show version` on r1 using
nothing but `curl` — no Python, no library — and pretty-print the JSON reply
with `jq`. You only do this once, but it removes all the magic: every
automation library you'll ever use is doing exactly this under the hood.

**Predict first:** if you send the right request with the **wrong password**,
what comes back — a JSON error message, or something at the HTTP layer?
Commit to an answer, then try it.

<details>
<summary>Hints</summary>

- The endpoint is `http://<router>/command-api`, credentials go in
  HTTP basic auth (`curl -u admin:admin`).
- The body is JSON-RPC 2.0: `method` is `runCmds`, and `params` is an object
  with `"version": 1`, a `"cmds"` list, and `"format": "json"`. An `"id"`
  field (any string) rounds it out.
- `-H 'Content-Type: application/json'` and `-d @-` (or `-d '{...}'`) to POST
  the body; pipe the output to `jq .`.

</details>

<details>
<summary>Solution</summary>

```bash
curl -s -u admin:admin -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "method": "runCmds",
    "params": {"version": 1, "cmds": ["show version"], "format": "json"},
    "id": "task3"
  }' \
  http://172.31.41.11/command-api | jq .
```

For the prediction test, repeat with `-u admin:wrongpassword` and add `-i` to
see the status line.

</details>

<details>
<summary>Check your work</summary>

You get a JSON-RPC envelope back: `"result"` is a **list with one element per
command** you sent, and element 0 contains structured fields like `version`,
`systemMacAddress`, `memTotal` — data, not text to regex through.

The wrong-password test resolves the prediction: authentication fails at the
**HTTP layer** with `401 Unauthorized`, before JSON-RPC is ever parsed. This
layering is the point — transport problems (refused, timeout), auth problems
(401/403), and command problems (a JSON-RPC `error` object in a 200 reply)
each live at a different layer, and Task 7 will make you tell them apart
under pressure.

</details>

## Task 4 — GET structured state with Python

**Objective:** Write `/workspace/bgp_report.py`: for every device in
`inventory.yml`, fetch `show ip bgp summary` via eAPI and print one line per
BGP peer — device, peer IP, peer AS, state, prefixes received. Running it
should give you a two-router health dashboard in one command.

**Predict first:** in the JSON you got for `show version`, the result was a
flat object. What *shape* do you expect `show ip bgp summary` to be — and
where will the peer state live? Sketch the path
(`result[0][...][...]`) before you print it.

<details>
<summary>Hints</summary>

- `inventory.yml` is already in `/workspace` — load it with
  `yaml.safe_load()`.
- `requests.post(url, json=payload, auth=(user, pw), timeout=5)` sends the
  same JSON-RPC body curl did; `resp.json()["result"]` is your data.
- Explore the shape interactively before writing the loop:
  `python3 -c '...; import json; print(json.dumps(data, indent=2))'` or just
  re-run the Task 3 curl with `"show ip bgp summary"` and read the jq output.
  The peers live under a VRF.
- Write the eAPI call as a function (`run_cmds(device, cmds)`) — you will
  reuse it in every remaining task.

</details>

<details>
<summary>Solution</summary>

```python
#!/usr/bin/env python3
"""bgp_report.py — BGP peer table for every device in the inventory."""
import requests
import yaml


def run_cmds(device, cmds, fmt="json"):
    payload = {
        "jsonrpc": "2.0",
        "method": "runCmds",
        "params": {"version": 1, "cmds": cmds, "format": fmt},
        "id": "bgp_report",
    }
    resp = requests.post(
        f"http://{device['host']}/command-api",
        json=payload,
        auth=(device["username"], device["password"]),
        timeout=5,
    )
    resp.raise_for_status()
    body = resp.json()
    if "error" in body:
        raise RuntimeError(body["error"]["message"])
    return body["result"]


def main():
    with open("inventory.yml") as f:
        inventory = yaml.safe_load(f)

    print(f"{'device':<8} {'peer':<16} {'AS':<7} {'state':<13} pfx-rcvd")
    for name, device in inventory["devices"].items():
        (summary,) = run_cmds(device, ["show ip bgp summary"])
        peers = summary["vrfs"]["default"]["peers"]
        for peer_ip, peer in peers.items():
            print(
                f"{name:<8} {peer_ip:<16} {str(peer.get('asn', '?')):<7} "
                f"{peer.get('peerState', '?'):<13} "
                f"{peer.get('prefixReceived', '?')}"
            )


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>Check your work</summary>

```
device   peer             AS      state         pfx-rcvd
r1       10.1.12.2        65002   Established   1
r2       10.1.12.1        65001   Established   1
```

The prediction: the result is **nested per-VRF** —
`result[0]["vrfs"]["default"]["peers"]` is a dict keyed by peer IP. Compare
this to parsing the *text* output of `show ip bgp summary` with regexes:
column widths shift, headers change between versions, and your parser breaks
silently. The JSON contract is the entire argument for model-driven
management. (Exact key names can shift slightly between EOS versions — which
is why the solution uses `.get()` with defaults for the per-peer fields.)

</details>

## Task 5 — Make a change, idempotently

**Objective:** Write `/workspace/ensure_loopback.py`: ensure `Loopback1`
exists on each router with the right address — `192.0.2.1/32` on r1,
`192.0.2.2/32` on r2. The script must be **idempotent**: it checks current
state first, only configures what's missing or wrong, and prints `CHANGED` or
`OK` per device accordingly.

**Predict first:** you will run the script twice. What exactly does the
second run print, and how many *config* API calls does it make? (Answering
the second part forces the design.)

<details>
<summary>Hints</summary>

- Read first: `show ip interface brief` returns an `interfaces` dict — if
  `Loopback1` is there, compare its `interfaceAddress.ipAddr` (`address` +
  `maskLen`) to the desired value.
- Config via eAPI is the same `runCmds` call, just with config-mode commands
  in sequence:
  `["enable", "configure", "interface Loopback1", "ip address ...", "end"]`.
- The idempotency lives in **your** code: eAPI happily re-applies config all
  day. Decide: desired == current → print `OK` and *do not* send config.

</details>

<details>
<summary>Solution</summary>

```python
#!/usr/bin/env python3
"""ensure_loopback.py — idempotently ensure Loopback1 on every device."""
import requests
import yaml

DESIRED = {
    "r1": "192.0.2.1/32",
    "r2": "192.0.2.2/32",
}


def run_cmds(device, cmds, fmt="json"):
    payload = {
        "jsonrpc": "2.0",
        "method": "runCmds",
        "params": {"version": 1, "cmds": cmds, "format": fmt},
        "id": "ensure_loopback",
    }
    resp = requests.post(
        f"http://{device['host']}/command-api",
        json=payload,
        auth=(device["username"], device["password"]),
        timeout=5,
    )
    resp.raise_for_status()
    body = resp.json()
    if "error" in body:
        raise RuntimeError(body["error"]["message"])
    return body["result"]


def current_loopback1(device):
    (brief,) = run_cmds(device, ["show ip interface brief"])
    iface = brief["interfaces"].get("Loopback1")
    if iface is None:
        return None
    addr = iface["interfaceAddress"]["ipAddr"]
    return f"{addr['address']}/{addr['maskLen']}"


def main():
    with open("inventory.yml") as f:
        inventory = yaml.safe_load(f)

    for name, device in inventory["devices"].items():
        desired = DESIRED[name]
        current = current_loopback1(device)
        if current == desired:
            print(f"{name}: OK (Loopback1 already {desired})")
            continue
        run_cmds(device, [
            "enable",
            "configure",
            "interface Loopback1",
            f"ip address {desired}",
            "description managed-by-automation",
            "end",
        ])
        print(f"{name}: CHANGED (Loopback1 {current} -> {desired})")


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>Check your work</summary>

First run: `CHANGED` on both devices. Second run: `OK` on both devices and
**zero** config calls — verify that claim by watching the script's behavior,
then confirm on a router that the config is there once, not duplicated:
`show running-config interfaces Loopback1`.

This check/apply split is what `ansible` modules, Terraform providers, and
every "declarative" tool implement internally. eAPI gave you none of it —
HTTP POST has no "make it so" semantics — so your script supplied the
idempotency. Hold that thought for the challenge questions, because NETCONF
and RESTCONF draw this line in a different place.

</details>

## Task 6 — Close the loop: change here, verify *there*

**Objective:** Write `/workspace/advertise_and_verify.py`: via the API,
configure r1 to advertise `192.0.2.1/32` (the Task 5 loopback) into BGP —
then prove the change worked by querying **r2** for the route, retrying for
up to ~10 seconds. Exit `0` with a success message if r2 has the route,
exit `1` if not. No CLI allowed; the script is the operator.

**Predict first:** roughly how long after the config call until r2 has the
route — milliseconds, seconds, or minutes? What BGP mechanics set that clock?

<details>
<summary>Hints</summary>

- The config side is one `runCmds` sequence:
  `router bgp 65001` → `address-family ipv4` → `network 192.0.2.1/32`.
  (A `network` statement only advertises a route that's already in the RIB —
  why did Task 5 conveniently put it there?)
- On r2, `show ip route 192.0.2.1/32` returns
  `vrfs.default.routes` — an **empty dict** until the route exists. That's
  your retry condition.
- `time.sleep(1)` in a bounded loop; `sys.exit(1)` on timeout so the script
  is usable in CI.

</details>

<details>
<summary>Solution</summary>

```python
#!/usr/bin/env python3
"""advertise_and_verify.py — change on r1, prove it on r2, all via API."""
import sys
import time

import requests
import yaml

PREFIX = "192.0.2.1/32"


def run_cmds(device, cmds, fmt="json"):
    payload = {
        "jsonrpc": "2.0",
        "method": "runCmds",
        "params": {"version": 1, "cmds": cmds, "format": fmt},
        "id": "advertise_and_verify",
    }
    resp = requests.post(
        f"http://{device['host']}/command-api",
        json=payload,
        auth=(device["username"], device["password"]),
        timeout=5,
    )
    resp.raise_for_status()
    body = resp.json()
    if "error" in body:
        raise RuntimeError(body["error"]["message"])
    return body["result"]


def main():
    with open("inventory.yml") as f:
        devices = yaml.safe_load(f)["devices"]
    r1, r2 = devices["r1"], devices["r2"]

    run_cmds(r1, [
        "enable",
        "configure",
        "router bgp 65001",
        "address-family ipv4",
        f"network {PREFIX}",
        "end",
    ])
    print(f"r1: '{PREFIX}' now advertised into BGP")

    for attempt in range(10):
        (routes,) = run_cmds(r2, [f"show ip route {PREFIX}"])
        table = routes["vrfs"]["default"]["routes"]
        if PREFIX in table:
            rtype = table[PREFIX].get("routeType", "?")
            print(f"r2: {PREFIX} present after ~{attempt}s (type {rtype})")
            sys.exit(0)
        time.sleep(1)

    print(f"r2: {PREFIX} NOT in routing table — verification FAILED")
    sys.exit(1)


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>Check your work</summary>

The script should report the route on r2 almost immediately — established
eBGP sessions send UPDATEs as soon as the new path is selected, so the answer
to the prediction is "well under a second" (your loop likely succeeds on
attempt 0). The route type on r2 is `eBGP`.

This is the full automation loop — **read, change, verify from a second
vantage point** — and it's the difference between "the config command
succeeded" and "the network actually did what I intended." Tools that skip
the third step automate outages.

</details>

## Task 7 — Break it: the API goes dark

**Objective:** From the lab directory on your host, run:

```bash
./break.sh
```

Your Task 4 script now fails against r1. Diagnose **from the symptom** and
restore API service to r1. Rule: you may use the router CLI to *inspect*
(`show ...`), but work the problem like an operator — transport layer first,
then auth, then the application — and name the failing layer before you fix
it. Don't read `break.sh`; that's the answer key.

**Predict first:** nothing to predict — you don't know the fault. Instead,
write down the *first two commands* you'll run, and what each one would rule
out, before running anything.

<details>
<summary>Hints</summary>

- Stuck on where to start: is it a network problem (`ping`), a TCP problem
  (`curl` to the port — what error *exactly*: timeout vs refused?), an auth
  problem (401?), or an application problem (JSON-RPC error)? Each gives a
  different error string — Task 3 taught you the layers.
- `show management api http-commands` on r1 — read *every* line this time,
  and compare against what it said in Task 2.
- "The API agent is running" and "the API is reachable on port 80" are
  different claims.

</details>

<details>
<summary>Solution</summary>

The fault: `break.sh` reconfigured r1's eAPI from HTTP to **HTTPS-only**:

```text
management api http-commands
   no protocol http
   protocol https
```

Symptom chain: ping to 172.31.41.11 works (L3 fine), but
`curl http://172.31.41.11/command-api` gets **connection refused** (nothing
listening on TCP/80) — while `show management api http-commands` shows the
agent **running**, because it is: on port 443, speaking TLS. The "service is
up" claim was true at the application layer and false on the transport your
clients use.

Fix (either is valid — re-enable HTTP to match the lab, or move your tooling
to HTTPS):

```text
configure
management api http-commands
   protocol http
end
```

Then re-run `bgp_report.py` and `./scripts/lab.sh check automation-fundamentals`
to confirm recovery.

</details>

<details>
<summary>Check your work</summary>

Recovery is proven when `bgp_report.py` prints both routers again and
`check.sh` passes. The diagnostic lesson: **"connection refused" with a
running agent means you're knocking on the wrong port/protocol**, not that
the service is down. In production this exact symptom appears when someone
hardens a device (HTTPS-only, new mgmt ACL) without updating the tooling —
the monitoring says "down", the device says "running", and both are right.

</details>

## Task 8 — Open: drift report

**Objective:** `desired_state.yml` in `/workspace` declares what each router
*should* look like: hostname, Loopback0 address, and BGP peers with their
expected state. Write `/workspace/drift_check.py` that compares **live**
state against that file and prints one `PASS`/`DRIFT` line per assertion,
exiting non-zero if anything drifted. Read-only — a drift checker that
"fixes" things is a different (and scarier) tool.

Then prove it works: change something by hand on r2 (shut its Loopback0, or
change the hostname), re-run, and watch the drift appear. Revert when done.

No step-by-step hints — you've written every building block already (Tasks
4–6). One nudge: `show hostname` returns JSON too.

<details>
<summary>Solution</summary>

```python
#!/usr/bin/env python3
"""drift_check.py — compare live state to desired_state.yml. Read-only."""
import sys

import requests
import yaml


def run_cmds(device, cmds, fmt="json"):
    payload = {
        "jsonrpc": "2.0",
        "method": "runCmds",
        "params": {"version": 1, "cmds": cmds, "format": fmt},
        "id": "drift_check",
    }
    resp = requests.post(
        f"http://{device['host']}/command-api",
        json=payload,
        auth=(device["username"], device["password"]),
        timeout=5,
    )
    resp.raise_for_status()
    body = resp.json()
    if "error" in body:
        raise RuntimeError(body["error"]["message"])
    return body["result"]


def live_state(device):
    hostname, brief, bgp = run_cmds(device, [
        "show hostname",
        "show ip interface brief",
        "show ip bgp summary",
    ])
    lo = brief["interfaces"].get("Loopback0")
    if lo is None:
        loopback0 = "missing"
    else:
        addr = lo["interfaceAddress"]["ipAddr"]
        loopback0 = f"{addr['address']}/{addr['maskLen']}"
    return {
        "hostname": hostname["hostname"],
        "loopback0": loopback0,
        "peers": bgp["vrfs"]["default"]["peers"],
    }


def main():
    with open("inventory.yml") as f:
        inventory = yaml.safe_load(f)["devices"]
    with open("desired_state.yml") as f:
        desired = yaml.safe_load(f)["devices"]

    drift = 0

    def report(device, label, want, got):
        nonlocal drift
        if str(want) == str(got):
            print(f"PASS   {device:<4} {label}: {got}")
        else:
            print(f"DRIFT  {device:<4} {label}: want {want}, got {got}")
            drift += 1

    for name, want in desired.items():
        got = live_state(inventory[name])
        report(name, "hostname", want["hostname"], got["hostname"])
        report(name, "loopback0", want["loopback0"], got["loopback0"])
        for peer in want["bgp_peers"]:
            state = got["peers"].get(peer["peer"], {}).get("peerState", "missing")
            report(name, f"bgp {peer['peer']}", peer["state"], state)

    sys.exit(1 if drift else 0)


if __name__ == "__main__":
    main()
```

</details>

<details>
<summary>Check your work</summary>

Clean network: six `PASS` lines (hostname, loopback0, one BGP peer — per
router), exit code 0 (`echo $?`). After you shut r2's Loopback0: its
`loopback0` line flips to `DRIFT` — and watch carefully whether anything
*else* drifts with it (did r1's BGP peering care? why not?). Revert, re-run,
all green.

You have now built, in ~60 lines, the read-side of what NetBox+validation
gave you in the `network-automation-netbox` lab and what commercial
assurance products sell: an executable definition of "healthy". The hard
production questions — where does desired state live, who updates it, how
often do you check — are the next lab's territory.

</details>

## Verification

From the repo root, with everything configured (Tasks 2–6 done, Task 7
repaired):

```bash
./scripts/lab.sh check automation-fundamentals
```

All checks should pass. Manually, you should be able to demonstrate:

- [ ] `show management api http-commands` reports running + HTTP on both routers
- [ ] `bgp_report.py` prints both peers `Established`
- [ ] `ensure_loopback.py` prints `OK` twice on its second run
- [ ] `advertise_and_verify.py` exits 0 (`echo $?`)
- [ ] `drift_check.py` is all `PASS` on a clean lab and catches a manual change

## Challenge questions

No answers provided — argue them from what you just built.

1. eAPI sends every request as a `POST` to one URL, with the "verb" buried in
   the JSON payload. Strict REST (and RESTCONF) would instead `GET
   /interfaces/Loopback1` and `PUT` a new body to it. What does the RESTCONF
   style buy you that `runCmds` can't — think caching, permissions, and what
   `PUT` means for your Task 5 idempotency code?
2. Your Task 5/6 config pushes sent a *list* of CLI commands. If command 4 of
   6 fails, what state is the router in? NETCONF answers this with candidate
   configuration and atomic commit. How would you approximate "all or
   nothing" with eAPI, and where does it leak?
3. The idempotency in Task 5 lives in your Python. List the failure modes
   that survive your check (two copies of the script racing? a typo in
   `DESIRED`? someone hand-editing the description?). Which of these would a
   declarative protocol eliminate, and which are eternal?
4. This lab runs eAPI over plain HTTP with `admin/admin` in a YAML file.
   Rank the things wrong with that for production, and name what you'd do
   about each — transport, credential storage, authorization granularity,
   and audit trail.
5. Scale the drift checker to 500 devices: checking each device every minute
   from one script won't hold. What breaks first, and how do agent-based vs
   agentless architectures, and streaming telemetry vs polling, each attack
   the problem?

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `curl: (7) ... Connection refused` | eAPI not enabled, or enabled but not on the protocol/port you're calling | Task 2 config; `show management api http-commands` and read the per-protocol lines |
| `curl` just hangs, then times out | Wrong IP (nothing there to refuse) | Check `inventory.yml` against `lab.sh status` mgmt IPs |
| HTTP `401 Unauthorized` | Wrong credentials | `admin`/`admin`, HTTP basic auth |
| Reply is HTTP 200 but contains an `error` object | A command in your `cmds` list failed (typo, wrong mode order) | Read `error.data` — it tells you which command; remember config sequences need `configure` first |
| `KeyError` parsing a result | Command output shape differs from assumption, or you asked for `format: "text"` | Dump the raw JSON (`json.dumps(..., indent=2)`) and re-derive the path; a few commands have no JSON model and return `format: "text"` only |
| Scripts work from your Mac/host but not in CI | You're calling the mgmt IPs, which only exist on the lab's docker network | Run from the automation container (`lab.sh shell ... automation`) |
| Router config "disappears" after lab restart | containerlab redeploy resets to `startup-config` files | Expected — that's what makes the lab repeatable; re-run your scripts (they're idempotent now, right?) |

## Extensions

- **gNMI**: the automation container ships `pygnmi`. Enable gNMI on the
  routers (`management api gnmi` → `transport grpc default`), then fetch
  interface state with a `gNMIclient` `get()` against an OpenConfig path and
  compare the experience — YANG paths and types vs eAPI's per-command JSON.
- **HTTPS properly**: switch eAPI to `protocol https`, make your `run_cmds`
  helper work against it (what do you do about the self-signed cert — and
  what *should* you do?), and re-run the whole suite.
- **Text fallback**: re-run Task 4 with `"format": "text"` and write the
  regex parser you've been spared. Keep it as a reminder.
- Move on to `network-automation-netbox` — same ideas, plus a real source of
  truth driving the templates.
