# Network GitOps and Safe Change Pipeline — Practice Lab

Build a local, inspectable change pipeline that turns versioned network intent
into a reviewed semantic diff, rejects unsafe changes before device access,
deploys through cEOS configuration sessions, verifies real service paths, and
uses explicit snapshots for rollback. This is GitOps as an operating mechanism:
versioned intent → review → validation → controlled deploy → independent
verification → reconciliation or rollback.

The lab does **not** claim a hosted CI product, Batfish model, production secrets
platform, or encrypted management transport. It proves the workflow locally with
real cEOS eAPI state and transactions.

The Python engine is supplied plumbing. The v2 intent, device template, semantic
tests, rendered output, and executable transaction/rollback/reconciliation
policy are withheld from the initial internal Git commit and are student-owned
work.

---

## Topology

```text
 corp/guest client
       |
     leaf1 ===== leaf2 ----- edge1 ----- app
       \           /
        \ observer/

 automation -- isolated management plane -- leaf1/leaf2/edge1
```

### Link addressing

| Link | Subnet | Left side | Right side | Purpose |
|---|---|---|---|---|
| client — leaf1 | `10.112.10.0/24` | corp `.10`, guest `.20` | `.1` | Real positive/negative source policy |
| leaf1 — leaf2 primary | `10.112.12.0/30` | `.1` | `.2` | Preferred redundant routed path |
| leaf1 — leaf2 backup | `10.112.12.4/30` | `.5` | `.6` | Higher-cost routed path |
| leaf2 — edge1 | `10.112.23.0/30` | `.1` | `.2` | Application transit |
| edge1 — app | `10.112.20.0/24` | `.1` | `.10` | HTTP service |
| observer — leaf1 | `10.112.31.0/30` | `.2` | `.1` | Independent observation attachment |
| observer — leaf2 | `10.112.32.0/30` | `.2` | `.1` | Independent observation attachment |

### Node reference

| Node | Loopback / data IP | Management IP | Role |
|---|---|---|---|
| `leaf1` | `10.0.12.1/32` | `172.31.112.11` | Client ingress, guest policy, first deploy target |
| `leaf2` | `10.0.12.2/32` | `172.31.112.12` | Redundant transit, second deploy target |
| `edge1` | `10.0.12.3/32` | `172.31.112.13` | Application edge, final deploy target |
| `client` | corp `.10`, guest `.20` | `172.31.112.21` | Executes real allowed and denied service probes |
| `app` | `10.112.20.10` | `172.31.112.22` | HTTP endpoint |
| `observer` | `.31.2`, `.32.2` | `172.31.112.23` | Dual-attached evidence point |
| `automation` | management only | `172.31.112.10` | Disposable Git repository and pipeline |

The lab-only credential is `admin/admin` over the isolated management network.
It is intentionally obvious and never written to attempt evidence.

---

## How to use this lab

This is a **practice lab**, not a tutorial. Each task gives you an
**objective** and **hints** — your job is to produce the configuration.

- **Predict before you configure.** When a task asks for a prediction,
  commit to an answer before touching the CLI. Being wrong and finding out
  why is the point.
- **Open the hints before the solution.** The solution toggle is the answer
  key — use it to check your work or when genuinely stuck, not as step one.
- **Verify like an operator.** After each task, prove the state is what you
  think it is with structured state and real service tests before moving on.

Do not inspect `configs/*/startup-config` during the student path. Addressing,
OSPF, policy, eAPI, and the internal repository skeleton are supplied plumbing,
not answers to the change-pipeline work.

## Deploy

Build the one repository-owned image, then deploy:

```bash
docker build -t network-gitops:local labs/network-gitops-change-pipeline/
./scripts/lab.sh deploy network-gitops-change-pipeline
./scripts/lab.sh check network-gitops-change-pipeline --baseline
./scripts/lab.sh bash network-gitops-change-pipeline automation
cd /workspace/lab-repo
```

The deploy is ready when the baseline check passes. The internal Git repository
is disposable and identified as `Network GitOps Lab
<gitops-lab@example.invalid>`. The outer repository is not mounted writable.

---

## Task 1 — Survey four sources of truth (guided)

**Objective:** distinguish declared design intent, rendered candidate, live
structured state, and real service truth before making a change.

**Predict first:** which source should answer “what do we want?” and which
should answer “what is actually forwarding right now?”

Run the survey:

```bash
python3 -m pipeline.cli survey --intent intent/baseline.yml
git log -1 --format='%H %an <%ae> %s'
```

<details markdown="1">
<summary>Hints</summary>

- Design truth is reviewable and versioned; current truth can drift.
- A correct configuration comparison does not prove the application path.

</details>

<details markdown="1">
<summary>Solution</summary>

Treat `intent/baseline.yml` as desired design, eAPI JSON as current device
truth, the Git commit as audit truth, and the client agent's corp/guest results
as service truth. None is a substitute for all the others.

</details>

<details markdown="1">
<summary>Check your work</summary>

The survey shows three `gitops-baseline` descriptions, no canary routes, corp
HTTP `200`, guest HTTP `000`, and an identified commit. This reveals why
“running config equals candidate” alone is an incomplete success condition.

</details>

---

## Task 2 — Complete deterministic rendering and schema tests (hinted)

**Objective:** create the v2 intent, a stable EOS command template, and semantic
tests that reject unknown devices, unsafe prefixes, management-plane changes,
and secret-like rendered content.

**Predict first:** should a default-route leak be rejected before or after the
first eAPI call? How will you prove the answer?

<details markdown="1">
<summary>Hints</summary>

- The JSON schema is already in `intent/schema.json`; inspect it.
- Put the change in `intent/change.yml` and template in
  `templates/device.j2`.
- Render `Loopback0` descriptions plus the approved
  `203.0.113.12/32` discard canary in sorted device order.
- Use `pytest` and render twice; compare SHA-256 values.

</details>

<details markdown="1">
<summary>Solution</summary>

The lab carries a collapsed recovery copy so you can compare your work:

```bash
cp /opt/gitops-solutions/intent/change.yml intent/change.yml
cp /opt/gitops-solutions/templates/device.j2 templates/device.j2
cp /opt/gitops-solutions/tests/test_intent.py tests/test_intent.py
pytest -q
python3 -m pipeline.cli render
```

</details>

<details markdown="1">
<summary>Check your work</summary>

`pytest` reports five passing tests. Two identical renders print the same three
SHA-256 values. No candidate contains `admin`, `password`, or `secret`. Stable
hashes make review evidence meaningful instead of order-dependent noise.

</details>

---

## Task 3 — Reject unsafe intent before device access (hinted)

**Objective:** prove syntax/schema, referential integrity, prefix policy,
management reachability, and blast-radius gates stop unsafe input without
opening an eAPI session.

**Predict first:** will the route-leak fixture fail on its prefix, administrative
distance, or both?

<details markdown="1">
<summary>Hints</summary>

- Use the `run` command so a rejected attempt still receives an evidence record.
- Inspect `evidence/*/summary.json`; a pre-check rejection must record
  `device_access_count: 0`.
- Test both `bad-route-leak.yml` and `bad-management.yml`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
python3 -m pipeline.cli run --intent intent/bad-route-leak.yml || true
python3 -m pipeline.cli run --intent intent/bad-management.yml || true
jq '{status,device_access_count,error}' \
  evidence/*/summary.json
```

</details>

<details markdown="1">
<summary>Check your work</summary>

Both attempts report `rejected_precheck`, and their device-access count is zero.
The route fixture violates both schema bounds and the one-prefix allow-list;
either independent guard is sufficient. The management fixture is rejected by
the protected-token gate.

</details>

---

## Task 4 — Produce a reviewable semantic change plan (hinted)

**Objective:** define the withheld transaction, rollback, verification, and
drift-reconciliation policy; then create normalized candidate hashes and a plan
naming devices, safe order, transient state, verification, and rollback trigger.

**Predict first:** while leaf1 is committed and leaf2 is not, what temporary
state is expected and what state would require a stop?

<details markdown="1">
<summary>Hints</summary>

- `plan` reads structured state and writes
  `rendered/change-plan.json`.
- Create `workflow/change-policy.yml`. Require running-config snapshots, EOS
  config sessions, staged stop-on-first-error commit, configure-replace
  rollback, structured plus independent service checks, and explicit
  adopt-or-revert drift disposition.
- Review semantic fields, not line-number noise.
- Confirm the repository commit and dirty flag are visible.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
cp /opt/gitops-solutions/workflow/change-policy.yml workflow/change-policy.yml
python3 -m pipeline.cli plan
jq '{change_id,repository,deploy_order,expected_transient_state,
     rollback_trigger,rollback_method,workflow,semantic_diff}' \
  rendered/change-plan.json
git diff -- intent/change.yml templates/device.j2 tests/test_intent.py \
  workflow/change-policy.yml
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The policy is executable student intent, not an engine default. The plan orders
`leaf1 → leaf2 → edge1`, names a snapshot/replace rollback, and shows only
loopback descriptions and the approved canary as semantic deltas. The expected
short-lived split is planned; an unexpected rejection is a stop and rollback
trigger.

</details>

---

## Task 5 — Commit and perform the controlled deploy (hinted)

**Objective:** commit reviewed intent, snapshot all devices, apply through named
configuration sessions in safe order, stop on any rejection, and retain a
complete per-attempt audit trail.

**Predict first:** are committed EOS configuration sessions sufficient for
rollback on this image? Use `PROBE.md` to justify your answer.

<details markdown="1">
<summary>Hints</summary>

- Commit only the four student-owned artifacts.
- The driver skips a device only when both structured fields already equal
  intent and no capability pre-command is pending.
- Each attempt stores candidate, pre-state, semantic diff, post-state, service
  result, timestamps, and snapshot names.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
git add intent/change.yml templates/device.j2 tests/test_intent.py \
  workflow/change-policy.yml
git commit -m "change: prefer reviewed v2 intent"
python3 -m pipeline.cli run
python3 -m pipeline.cli history
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The successful summary names all three devices in `changed`, includes three
flash snapshots, and reports corp allowed/guest denied. Config sessions provide
candidate isolation but retain only one completed session and do not autosave;
rollback uses the explicit snapshots proven in `PROBE.md`.

</details>

---

## Task 6 — Verify independently and prove idempotency (hinted)

**Objective:** compare structured fleet state with intent, run real corp/guest
service paths, and prove a second run changes zero devices.

**Predict first:** if all generated lines exist but the guest path works, should
the change be successful?

<details markdown="1">
<summary>Hints</summary>

- `verify` queries eAPI and asks the client-side agent to originate both
  identities.
- Run the pipeline a second time and inspect `changed` plus `idempotent`.
- Observe OSPF independently with `show ip ospf neighbor`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
python3 -m pipeline.cli verify
python3 -m pipeline.cli run
python3 -m pipeline.cli history
```

From the host:

```bash
./scripts/lab.sh cli network-gitops-change-pipeline leaf1
show ip ospf neighbor
show ip route 203.0.113.12/32
```

</details>

<details markdown="1">
<summary>Check your work</summary>

All semantic diffs are empty, corp receives HTTP `200`, guest remains denied,
and the second attempt records `idempotent: true` with `changed: []`. A guest
success would fail the attempt even if configuration were equivalent.

</details>

---

## Task 7 — Trigger a post-check rollback (hinted)

**Objective:** make a syntactically valid change fail its post-check, restore
all snapshots automatically, and retain the failed attempt without leaking
credentials.

**Predict first:** should rollback erase the evidence of why it happened?

<details markdown="1">
<summary>Hints</summary>

- Generate the bounded fixture from the already reviewed v2 intent.
- The forced failure occurs only after device and service observations.
- After rollback, verify against normal `intent/change.yml`.

</details>

<details markdown="1">
<summary>Solution</summary>

```bash
python3 -m pipeline.cli make-postcheck-fixture
python3 -m pipeline.cli run --intent intent/postcheck-failure.yml || true
python3 -m pipeline.cli verify
python3 -m pipeline.cli history
grep -R -E 'admin|EAPI_PASSWORD|Authorization' evidence/ && echo LEAK || echo CLEAN
rm -f intent/postcheck-failure.yml
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The failed attempt reports `failed_rolled_back`, lists all three devices under
`rollback`, and leaves v2 state plus both service invariants healthy. Candidates,
post-check output, timestamps, and rollback events remain; credentials do not.

</details>

---

## Task 8 — Decide adopt versus revert for emergency drift (open)

**Objective:** detect an out-of-band change, decide whether the change is
authorized, and either produce reviewable adopted intent or reconcile the device
to the committed source of truth.

**Predict first:** what evidence and approval would make adoption safer than
reversion?

<details markdown="1">
<summary>Hints</summary>

- Inject only the bounded lab drift, then run `drift`.
- `reconcile --mode adopt` writes a proposed `intent/adopted.yml` without
  touching the device.
- `reconcile --mode revert` changes the device and should make `drift` exit zero.

</details>

<details markdown="1">
<summary>Solution</summary>

One defensible lab decision is to inspect the proposed adoption, reject it
because no approved change exists, then revert:

```bash
python3 -m pipeline.cli inject-drift --device leaf1
python3 -m pipeline.cli drift || true
python3 -m pipeline.cli reconcile --mode adopt --device leaf1
git diff --no-index intent/change.yml intent/adopted.yml || true
python3 -m pipeline.cli reconcile --mode revert --device leaf1
python3 -m pipeline.cli drift
rm -f intent/adopted.yml
```

</details>

<details markdown="1">
<summary>Check your work</summary>

Drift reports the running `emergency-manual-change` against committed
`gitops-v2`. Adoption creates a review artifact but never silently legitimizes
it. Reversion restores empty semantic diffs, and another reversion is
idempotent.

</details>

---

## Task 9 — Break-It: recover from a partial push (open)

**Objective:** diagnose a pipeline that exited after device 1 accepted v3 and
device 2 rejected stale capability data. Prevent later stages, roll back device
1, repair authoritative inventory, and rerun from a clean reviewed commit.

**Symptom:** the pipeline exits non-zero. Corp service still works, but fleet
descriptions disagree and no success record exists for the attempt.

From the host:

```bash
./labs/network-gitops-change-pipeline/break-it.sh
./scripts/lab.sh check network-gitops-change-pipeline --success
```

The check must fail while the split state exists.

<details markdown="1">
<summary>Hints</summary>

- Do not push forward to `edge1`.
- Start with `python3 -m pipeline.cli history`, the newest `summary.json`, and
  `state-before.json`.
- Compare `git show HEAD` with device session state. The authoritative inventory
  claims an invalid leaf2 address capability.
- Roll back only devices recorded as applied, then revert the bad Git commit.

</details>

<details markdown="1">
<summary>Solution</summary>

From the host:

```bash
./labs/network-gitops-change-pipeline/repair-break-it.sh
./scripts/lab.sh check network-gitops-change-pipeline
```

The repair script performs the inspectable operations:

```bash
python3 -m pipeline.cli rollback
git revert --no-edit HEAD
python3 -m pipeline.cli run
```

</details>

<details markdown="1">
<summary>Check your work</summary>

The failed summary reports `partial`, `applied: ["leaf1"]`,
`failed_device: "leaf2"`, and `stopped_before: ["edge1"]`. Repair changes that
attempt to `partial_rolled_back`, records the snapshot used, reverts the stale
inventory/intent commit, and returns all devices and service paths to v2.

</details>

---

## Verification

Run the complete end-state and evidence gate from the host:

```bash
./scripts/lab.sh check network-gitops-change-pipeline
```

It asserts schema/references, deterministic secret-safe rendering, rejected
route and management candidates with zero API calls, successful structured
state, corp allow/guest deny, idempotency, drift adopt/revert, partial-push
detection, post-check rollback, evidence redaction, and the outer-repository
boundary.

Make the mechanism visible at any time:

```bash
./scripts/lab.sh cmd network-gitops-change-pipeline automation -- \
  sh -lc 'cd /workspace/lab-repo && python3 -m pipeline.cli history'
./scripts/lab.sh cmd network-gitops-change-pipeline automation -- \
  sh -lc 'cd /workspace/lab-repo && jq . evidence/*/semantic-diff.json'
./scripts/lab.sh cmd network-gitops-change-pipeline observer -- \
  tcpdump -ni eth1 -c 10
```

## Challenge questions

1. How would you preserve rollback if devices reboot between snapshot and
   verification, without treating startup-config as an unreviewed side effect?
2. Which changes need a topology-wide transaction, and which are safer with
   staged commit plus rollback? Rank three examples by blast radius.
3. What additional evidence would justify adopting emergency drift during an
   incident rather than reverting it?
4. How would you protect the local credential and eAPI transport in production
   while keeping evidence independently auditable?
5. Where would a model-based tool add material value beyond this lab's explicit
   prefix, policy, route, and service tests?

## Troubleshooting

| Symptom | Likely cause | Minimal repair |
|---|---|---|
| `templates/device.j2 is missing` | Task 2 is incomplete | Write the template or reveal the Task 2 recovery copy |
| eAPI connection refused just after deploy | cEOS agents are still starting | Retry through the bounded baseline check; do not use a fixed long sleep |
| Internal Git working tree is dirty before Break-It | Student artifacts were not reviewed/committed | Review and commit them; do not discard unknown work |
| `partial application preserved for diagnosis` | A later device rejected after an earlier commit | Inspect evidence, roll back only `applied`, repair intent/inventory, rerun |
| Corp and guest both work | Guest ACL/service invariant is broken | Stop success reporting and restore the bounded network policy |
| Pipeline refuses the current directory | Command ran outside `/workspace/lab-repo` | Enter the disposable internal repository; never point it at the outer repository |

## Cleanup

```bash
./scripts/lab.sh destroy network-gitops-change-pipeline --cleanup
```

Destroying the topology intentionally removes the internal Git repository,
attempt evidence, cEOS flash snapshots, containers, and the scoped management
network. A redeploy begins again from the single identified baseline commit.
