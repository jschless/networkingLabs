# Advanced Enterprise Network Engineering Expansion Plan

> **Status: PLANNING COMPLETE — implementation not started.** This is the master
> roadmap for broadening the repository beyond ENCOR/ENARSI into a practical,
> advanced-enterprise network engineering curriculum. Each implementation work
> package has a self-contained build plan under `plans/enterprise-expansion/`.

## 1. Program outcome

The finished curriculum should prepare an enterprise network engineer to design,
build, observe, troubleshoot, and explain networks spanning:

- campus LAN and wireless;
- traditional and software-defined WAN;
- internet transit and public/private peering;
- cloud and hybrid connectivity;
- single-site data-center fabrics and multi-site DCI;
- private mobile infrastructure;
- carrier handoffs, physical cross-connects, and legacy-service boundaries;
- identity-aware secure access and advanced network security;
- dual-stack network services;
- voice, OT/IoT, and storage-networking seams;
- automated change, validation, rollback, and evidence-driven operations.

The goal is not to claim that containers reproduce RF, optics, ASICs, cellular
radio, or Fibre Channel hardware. The goal is to make the live mechanisms live,
and to teach non-emulatable mechanisms through clearly labeled evidence-analysis
exercises rather than synthetic counters presented as real hardware behavior.

## 2. Authoring contract

Every implementation agent must read these files before acting:

1. `.claude/skills/new-lab/SKILL.md` — repository lab-builder workflow.
2. `labs/AUTHORING.md` — teaching and README contract.
3. `docs/contributing.md` — file, docs, image, and validation requirements.
4. The assigned work-package plan under `plans/enterprise-expansion/`.
5. For blind incidents, `labs/troubleshooting-range/scenarios/AUTHORING.md` and
   the installed troubleshooting-ticket skill.

Where the older `new-lab` skill says `topology.yml`, follow the repository's
current convention and use **`topology.clab.yml`**. Use `./scripts/lab.sh` in
student documentation. A normal lab ships at minimum:

```text
labs/<name>/
  topology.clab.yml
  README.md
  check.sh
  configs/...
docs/tracks/<track>/<name>.md
```

It must also be registered in the track index, `docs/index.md`, `mkdocs.yml`,
and, when introducing an image, `docs/getting-started.md`.

## 3. What counts as coverage

The new enterprise-wide coverage map will use these maturity levels. A topic is
not called “covered” merely because a README mentions it.

| Level | Name | Acceptance evidence |
|---:|---|---|
| 0 | Absent | No maintained material |
| 1 | Evidence/theory | Curated explanation or authentic/synthetic-labeled evidence pack |
| 2 | Reference | Working deployment exposes the mechanism and has automated checks |
| 3 | Practice | Student produces the core configuration from objectives and hints |
| 4 | Troubleshooting | Symptom-led Break-It exercise requires diagnosis and minimal repair |
| 5 | Blind assessed | Runtime injector, idempotent clear, end-to-end verifier, proctor rubric, live dry run |

Program target:

- Common enterprise domains: level 4 minimum, level 5 for representative faults.
- Specialist domains: level 3 or 4, with level 1 evidence where hardware fidelity
  is impossible.
- Product-only workflows: level 1, explicitly named as product/sandbox work.

## 4. Lab quality gates

Every work package follows the same gates. An agent may not skip directly from
design to a polished README.

### Gate A — feature probe

- Prove the exact required behavior on the exact local image and host kernel.
- Use the smallest disposable topology possible.
- Record commands, versions, result, resource use, and unsupported behavior in
  `labs/<name>/PROBE.md` or the package status log.
- If the probe fails, take only the documented fallback. Never silently replace
  a real feature with a mock and retain the original claim.

### Gate B — instructional design

- IPs, names, base interfaces, certificates, and unrelated service plumbing are
  prebuilt.
- The feature being taught is withheld from startup state.
- Tasks ramp guided (at most 20%) → hinted (roughly 60–70%) → open (15–20%).
- Every core task has Objective, useful Predict prompt where applicable, Hints,
  collapsed Solution, and mechanism-oriented Check Your Work.
- At least one task makes an invisible mechanism visible by capture, protocol
  table, transaction log, or state comparison.
- At least one Break-It starts from a user-visible symptom and requires diagnosis.

### Gate C — automated validation

- `check.sh` uses `scripts/check-lib.sh` and tests the real data and control paths.
- Negative policy tests are included, not only positive pings.
- A check must fail for the planned break state and pass after the minimal repair.
- Time-bounded retries cover real convergence without fixed long sleeps.

### Gate D — clean live walk

From a clean state:

1. Build all required images.
2. Deploy and wait only through documented readiness gates.
3. Perform every student task without using source configs as an answer key.
4. Run every visible verification command and compare actual output with README claims.
5. Run every Break-It, diagnose it from evidence, apply the documented minimal fix,
   and rerun `check.sh`.
6. Destroy with cleanup, redeploy, and prove the starting state is blank/healthy.
7. Record peak memory, steady memory, deploy time, and teardown behavior.

### Gate E — repository validation

```bash
python3 scripts/lint-labs.py
./scripts/check-docs-admonitions.sh
mkdocs build --strict
shellcheck -S warning scripts/*.sh labs/*/check.sh
```

Package-specific validators supplement, not replace, these commands.

## 5. Platform and fidelity rules

- Prefer cEOS `ceos:4.35.2F` for enterprise routing/switching when the feature
  probe succeeds.
- Use SR-Linux only when the plan explicitly benefits from its modeled NOS or
  native data plane.
- Use FRR as a routing platform only when cEOS lacks the exact behavior or when
  resource density makes the learning objective otherwise impractical; document
  the reason.
- Use Linux for endpoints, services, namespaces, traffic generation, packet
  capture, security policy, and cloud/mobile/storage analogues.
- Pin all third-party images by version or digest. Do not use an unqualified
  mutable `latest` in a new lab.
- No lab should require internet access after its one-time image build/pull unless
  the README says so prominently.
- Keep each separately deployed package below 11 GiB steady-state on the current
  ~15 GiB lab host, with at least 3 GiB host headroom. Target lower where possible.

## 6. Work packages

| ID | Work package | Primary deliverable(s) | Target level | Plan |
|---:|---|---|---:|---|
| 00 | Enterprise coverage framework | Enterprise-wide coverage map and status tooling | — | This file, Phase 0 |
| 01 | Cloud and hybrid networking | `cloud-hybrid-networking` | 4 | [`01-cloud-hybrid-networking.md`](plans/enterprise-expansion/01-cloud-hybrid-networking.md) |
| 02 | Wireless operations | `wireless-core-operations`, RF evidence pack | 4/1 | [`02-wireless-core-operations.md`](plans/enterprise-expansion/02-wireless-core-operations.md) |
| 03 | Data-center interconnect | `dci-evpn-multisite` | 4 | [`03-dci-evpn-multisite.md`](plans/enterprise-expansion/03-dci-evpn-multisite.md) |
| 04 | Carrier and legacy cross-connects | `carrier-ethernet-handoff`, cross-connect evidence pack | 4/1 | [`04-carrier-cross-connects.md`](plans/enterprise-expansion/04-carrier-cross-connects.md) |
| 05 | Private mobile infrastructure | `private-5g-enterprise`, `mobile-transport-timing` | 4/3 | [`05-private-5g-enterprise.md`](plans/enterprise-expansion/05-private-5g-enterprise.md) |
| 06 | Zero-trust secure access | `zero-trust-secure-access` | 4 | [`06-zero-trust-secure-access.md`](plans/enterprise-expansion/06-zero-trust-secure-access.md) |
| 07 | Internet peering operations | `internet-peering-ixp` | 4 | [`07-internet-peering-ixp.md`](plans/enterprise-expansion/07-internet-peering-ixp.md) |
| 08 | Systemic dual stack | `enterprise-dual-stack-capstone` | 4 | [`08-enterprise-dual-stack-capstone.md`](plans/enterprise-expansion/08-enterprise-dual-stack-capstone.md) |
| 09 | Voice/collaboration networking | `enterprise-voice-sip-qos` | 4 | [`09-enterprise-voice-sip-qos.md`](plans/enterprise-expansion/09-enterprise-voice-sip-qos.md) |
| 10 | OT/IoT networking | `ot-zone-conduit` | 4 | [`10-ot-zone-conduit.md`](plans/enterprise-expansion/10-ot-zone-conduit.md) |
| 11 | Storage networking | `dc-storage-networking`, FC/RoCE evidence pack | 4/1 | [`11-dc-storage-networking.md`](plans/enterprise-expansion/11-dc-storage-networking.md) |
| 12 | Production automation | `network-gitops-change-pipeline` | 4 | [`12-network-gitops-change-pipeline.md`](plans/enterprise-expansion/12-network-gitops-change-pipeline.md) |
| 13 | SD-WAN operations | `sdwan-operations` or honestly named orchestrated overlay | 4 | [`13-sdwan-operations.md`](plans/enterprise-expansion/13-sdwan-operations.md) |
| 14 | Advanced security architecture | `advanced-security-architecture` | 4 | [`14-advanced-security-architecture.md`](plans/enterprise-expansion/14-advanced-security-architecture.md) |
| 15 | Global application delivery | `global-application-delivery` | 4 | [`15-global-application-delivery.md`](plans/enterprise-expansion/15-global-application-delivery.md) |
| 16 | Blind assessment expansion | New domain-specific persistent ranges and tickets | 5 | [`16-assessment-ranges.md`](plans/enterprise-expansion/16-assessment-ranges.md) |

## 7. Dependency and implementation order

```text
Phase 0: coverage framework + shared fixtures conventions
   |
   +--> 01 cloud -----------+
   +--> 02 wireless --------+
   +--> 06 zero trust ------+--> 16 hybrid/access assessment range
   +--> 08 dual stack ------+
   +--> 13 SD-WAN ----------+
   +--> 15 app delivery ----+
   |
   +--> 03 DCI -------------+
   +--> 04 carrier ---------+
   +--> 07 peering ---------+--> 16 DC/edge assessment range
   +--> 11 storage ---------+
   +--> 14 security --------+
   |
   +--> 05 private 5G ------+
   +--> 09 voice -----------+--> 16 specialized-services range
   +--> 10 OT/IoT ----------+
   |
   +--> 12 GitOps (best after 01, 03, and 08 establish broader inventory patterns)
```

Recommended serial order for one builder:

1. Phase 0 documentation and validators.
2. Cloud, DCI, wireless, carrier, private 5G.
3. Zero trust, peering, dual stack.
4. SD-WAN operations, advanced security, application delivery, voice, OT, storage,
   and GitOps.
5. Persistent assessment ranges only after their source labs have passed Gate D.

Packages 01–11 and 13–15 may be delegated in parallel only after their feature
probes are isolated. Package 12 depends on stable lab inventories. Package 16 is
serial per range because `range.sh`, topology, health gate, and catalogs are shared files.

## 8. Phase 0 — shared program infrastructure

- [ ] Add `docs/enterprise-coverage-map.md` using the level 0–5 model above.
- [ ] Map current labs and all planned packages across campus, WAN, cloud, DC/DCI,
      internet edge, wireless, mobile, security, operations, IPv6, carrier/physical,
      voice, OT, and storage.
- [ ] Keep `docs/coverage-map.md` as the exam-specific map; cross-link the two.
- [ ] Add a machine-readable `docs/enterprise-coverage.yaml` with fields:
      `domain`, `topic`, `level`, `labs`, `fidelity`, `last_live_validation`,
      `owner`, and `notes`.
- [ ] Add a validator that rejects unknown levels, missing lab paths, a level 3+
      topic without `check.sh`, and a level 5 topic without scenario metadata.
- [ ] Establish `labs/fixtures/README.md` rules: provenance, license, capture method,
      anonymization, synthetic labeling, expected deductions, and checksums.
- [ ] Add a standard `PROBE.md` template and a `VALIDATION.md` template.
- [ ] Decide and document third-party image pinning and vulnerability-refresh policy.
- [ ] Fix existing documentation drift before changing counts: stale “planned” labels
      in `docs/study-paths.md` and nonexistent data-center variant links.

## 9. Delegation contract

Give a future agent exactly one work-package file and this master plan. The agent
owns only its new lab directory, wrapper page, and package status entry until the
feature probe passes. Shared-file edits (`mkdocs.yml`, `docs/index.md`, track index,
coverage YAML) are made at the end of that package or by a designated integration
owner; do not let multiple unmerged branches edit counts simultaneously.

For unattended serial execution on the single-test lab host, use the reusable
[`SEQUENTIAL-ORCHESTRATOR-PROMPT.md`](plans/enterprise-expansion/SEQUENTIAL-ORCHESTRATOR-PROMPT.md).
It creates only one worker task at a time and makes PR merge policy explicit before
the next branch is cut.

One branch and PR per deliverable, based on current `main`; never stack branches.
Default branch prefix in this environment is `codex/`. A package with two labs may
use one probe PR followed by one PR per lab if the probe changes reusable images or
fixtures.

An implementation handoff must include:

- probe result and exact image versions;
- files created and shared files changed;
- clean deploy/check/break/fix/redeploy evidence;
- unsupported or evidence-only behaviors;
- peak/steady memory and deploy time;
- all validator output;
- remaining follow-up, with no unvalidated extension represented as complete.

## 10. Explicit non-goals

- Do not retrofit every existing lab to IPv6 in this program; build the dual-stack
  capstone first, then decide migrations from evidence.
- Do not turn this into vendor-product button training. Product workflows may be
  companion evidence/sandbox exercises, but core mechanisms remain vendor-transferable.
- Do not count untracked runtime artifacts under `labs/opnsense-ngfw-basics/` as a
  delivered security lab. Preserve them and coordinate before any security package
  touches that path.
- Do not build blind tickets before a healthy-state gate can prove the required
  service and control-plane behavior.
- Do not simulate RF power, optical receive power, ASIC counters, hardware PTP, or
  Fibre Channel fabric behavior and present it as live measurement.

## 11. Program definition of done

The expansion is complete only when:

- all packages 00–15 meet their target coverage level;
- package 16 has at least two live-dry-run tickets per common enterprise domain and
  representative specialist tickets where the topology is reliable;
- the coverage validator and docs build are green;
- each level 3+ topic has a dated clean live validation record;
- the assessment ranges have completed at least one human pilot and adjusted time
  bands/rubrics from observed behavior;
- the public docs clearly distinguish live, emulated, evidence-only, product-only,
  optional-licensed, and hardware-required material.

## 12. Status log

| Date | Item | Status / notes |
|---|---|---|
| 2026-07-21 | Assessment | Repository judged strong in advanced IP networking but incomplete across cloud, real wireless, DCI, private cellular, carrier/physical operations, zero trust, and several specialist seams. |
| 2026-07-21 | Detailed planning | Master program contract and 16 agent-ready work-package plans created. No implementation started. |
