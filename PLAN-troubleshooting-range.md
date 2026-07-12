# Troubleshooting Range Plan — helpdesk-tier assessment labs

> **Status: ACTIVE roadmap (created 2026-07-12).** Read this first when resuming
> work on the troubleshooting range. Update checkboxes + the status log on merge,
> same convention as the (archived) gap-closure `PLAN.md`.

## What this builds

A **troubleshooting range**: one persistent enterprise topology that stays running
across many assessment sessions, plus a catalog of injectable fault scenarios
("tickets"), proctor rubrics, and a grading workflow. Purpose: assess what helpdesk
tier (1/2/3) a network engineer is qualified to provide, by simulating the neteng
help desk — the engineer gets a symptom, not a cause, and must diagnose, fix, and
verify while every command they run is captured for grading.

## Decided requirements (2026-07-12 session — do not re-litigate without Joe)

- **Platform:** FRR core/distribution/WAN + **2–3 cEOS nodes at access/edge**
  (vendor-CLI realism where assessment needs it). Linux service containers.
- **Runs on the lab host only** (192.168.0.26, ~15 GB). Not sized for the Mac.
  All work — including agent builds — happens on the lab host or over SSH; the
  whole workflow is CLI-only (Joe, 2026-07-12).
- **Ticket scope:** diagnose + **fix** + verify, all tiers. The `verify` script
  must catch symptom-masking (a static route papering over a dead adjacency fails).
- **Grading:** human supervisor + rubric + **captured timestamped command
  transcript** (`script(1)` wrapper). Automated/AI grading is a later wave.
- **Reset without teardown:** runtime inject/clear (grand-capstone `faults.sh`
  pattern — mutate in-container copies, never bind-mounted sources). cEOS resets
  via `configure replace` from golden; FRR via vtysh config reload. A health gate
  proves golden state before every task and after every clear. Full redeploy is
  the escape hatch, not the loop.
- **Tiers = difficulty bands:** T1 symptom-near-cause → T2 one layer removed →
  T3 cross-layer/compound. Qualification = N blind-drawn scenarios per tier
  within time bands.
- **Integrity:** blind draw + parameterized fault locations where cheap. Rubrics
  stay in-repo plaintext (internal tool).
- **Waves:** 1 = pure networking; 2 = infra services (DNS/DHCP/NTP); 3 =
  enterprise app-layer. The topology reserves the services block from day one.
- **Scenario anatomy:** `ticket.md` (symptom as reported, never the cause) +
  `rubric.md` (proctor-only: root cause, diagnostic decision tree with per-step
  deductions, red flags, point weights, time band) + self-verifying
  `inject`/`clear` + `verify`.

## Working conventions

Same as ever: one branch + PR per deliverable, **never stack branches**. Scenario
work is parallelizable because each scenario is a disjoint directory — but any
shared file (catalog index, `range.sh`) is owned by one branch at a time.
Definition of done for a **scenario**: health gate green → `inject` (self-verifies
symptom) → *walk the rubric's diagnostic path yourself and confirm each step
yields the deduction the rubric claims* → fix per rubric → `verify` green →
`clear` → health gate green again. Definition of done for **range/tooling
changes**: clean deploy → health gate → inject/clear one scenario per tier →
destroy → redeploy.

Lab lives at `labs/troubleshooting-range/`; scenarios under
`labs/troubleshooting-range/scenarios/<tier>-<slug>/`.

---

## Phase 0 — Access + load-bearing prototypes (serial; everything depends on these)

- [ ] **0.0 Lab-host working setup** — get the agent workflow running on the lab
      host (Claude Code on the host itself, or SSH from the Mac — note the June
      2026 finding that the host rejected key auth; fix keys or run locally).
      Confirm: repo clone, image builds (`frr-lab:local`, cEOS import), a clab
      deploy/destroy cycle, and free-RAM headroom measured. Record the chosen
      workflow here for future sessions.
- [ ] **0.1 `DESIGN.md`** — topology + addressing plan + RAM budget. Sketch to
      refine: ISP node → edge firewall/NAT (FRR+nftables) → core pair (FRR,
      OSPF + VRRP or routed) → **cEOS access pair** with corp/voice/guest VLANs;
      one branch site over a WAN link (FRR); services block (bind9 DNS, Kea DHCP
      + relay, nginx web, syslog/NTP — lightweight, Wave-2/3-ready); endpoint
      containers per VLAN + branch. Target ≤ ~18 nodes, ≤ ~8 GB steady-state
      (3 cEOS ≈ 4.5 GB is the bulk). Include: golden-config layout, a
      `topology_version` field scenarios pin to, and the attempt-directory format.
- [ ] **0.2 Prototype: no-restart reset (THE load-bearing unknown).** Prove on a
      3-node throwaway (1 cEOS + 1 FRR + 1 Linux host): break each node, then
      restore golden **without container restarts** — cEOS `configure replace
      flash:golden.cfg`, FRR config reload via vtysh/frr-reload, Linux node reset
      script (routes/addr/nft/processes). Measure reset time (target: seconds,
      not minutes) and document what does NOT revert (ARP/MAC tables, conntrack,
      counters, DHCP leases) → the reset script must flush those explicitly.
      If cEOS config-replace proves unreliable, fallback is scripted
      inverse-diffs per scenario — decide here, before Phase 1 hard-codes either.
- [ ] **0.3 Prototype: transcript capture.** `script(1)`-wrapped node shell with
      per-command timestamps (util-linux `script --log-timing` or equivalent in
      the container/host), filed under a per-attempt directory with scenario id +
      start/stop times. Must survive the engineer opening shells on several nodes
      in parallel. This is the evidence layer grading depends on.

## Phase 1 — Build the range

- [ ] **1.1 Topology + golden state.** `topology.clab.yml`, golden configs for
      every node, deploy scripting, and the **health gate** (`range.sh status` →
      NN/NN checks: adjacencies, VRRP state, DHCP lease grant, DNS resolution,
      end-to-end paths incl. branch + internet). Gate must be fast (< ~30 s) —
      it runs before/after every task.
- [ ] **1.2 `range.sh`** — the proctor tool: `deploy` / `destroy` / `status` /
      `start <scenario|--tier N>` (blind draw for `--tier`) / `reset` /
      `shell <node>` (transcript-wrapped) / `attempt` management (open attempt id,
      file transcripts, record start/stop for time-band grading). Start prints the
      ticket only — never the scenario slug's cause.
- [ ] **1.3 Engineer docs pack.** Student-facing README (range orientation, how
      tickets work, what's expected in a write-up), topology diagram, IP plan,
      and a `known-good/` directory of reference outputs (the docs a real
      helpdesk engineer would have). Rubric-free.

## Phase 2 — Scenario framework, proven by two reference scenarios

- [ ] **2.1 `scenarios/AUTHORING.md`** — the scenario contract: directory format,
      metadata header (tier, domain, est. time band, `topology_version`,
      parameterization axes), rubric template (decision tree + per-step points +
      red-flag deductions + pass threshold), the scenario definition-of-done from
      "Working conventions" above. Extends `labs/AUTHORING.md`; link both ways.
- [ ] **2.2 Two hand-built reference scenarios** — one T1 (e.g. access port
      admin-down / wrong VLAN) and one T3 (e.g. "web is down" but the cause is a
      lost route to DNS) — built end-to-end through the contract, then a **full
      dry run**: inject via `range.sh start`, work the ticket as the engineer in
      a transcript-wrapped shell, grade the transcript against the rubric as the
      supervisor. Fix everything that grates before mass-producing Phase 3.

## Phase 3 — Wave 1 catalog (10 more scenarios → 12 total, 4 per tier)

Parallelizable across agents once 2.1/2.2 merge (disjoint scenario dirs; catalog
index updated per-PR). Candidate pool — final pick + parameterization decided at
build time, aim for spread across L1–L4 and across nodes:

- [ ] **3.1 T1 batch** (+3): DHCP pool exhausted; server with wrong
      gateway/netmask; access-port link down (or err-disable analogue);
      trunk missing a VLAN.
- [ ] **3.2 T2 batch** (+3): OSPF MTU mismatch (stuck EXSTART); ACL blocking
      return traffic only; NAT/masquerade broken for one subnet; PMTUD blackhole
      (DF + filtered ICMP); BGP route-map dropping the branch prefix.
- [ ] **3.3 T3 batch** (+3): VRRP dual-master via filtered peer traffic;
      asymmetric routing breaking stateful firewall flows; DDNS chain broken
      (new leases resolve nothing — DHCP "works", DNS "works"); intermittent path
      degradation (netem loss on one ECMP member); redistribution loop.
- [ ] **3.4 Catalog index + docs registration** — scenario table (tier/domain/
      time band) in the lab README; register the lab in the docs site + tracks
      the way every lab is registered.

## Phase 4 — Assessment kit + pilot

- [ ] **4.1 Grading guide + tier qualification doc.** How a supervisor runs an
      assessment end to end. Proposed starting numbers (tune in 4.2): draw 3 of 4
      scenarios per tier; time bands T1 ≤ 15 min / T2 ≤ 35 min / T3 ≤ 60 min;
      pass = ≥ 70% rubric points on every drawn scenario **and** `verify` green;
      red-flag caps (shotgun config changes, no verification step) that gate the
      grade regardless of points.
- [ ] **4.2 Pilot assessment.** Run a real human (Joe or a colleague) through a
      full T1→T3 draw using only the proctor docs. Fix every rubric step that
      didn't match what a reasonable engineer actually did; record timing data;
      adjust bands/thresholds; note results here.

## Phase 5 — Later waves (unscheduled; do not start without a fresh decision)

- Wave 2: infra-service faults (DNS resolution chains, DHCP relay/DDNS, NTP skew).
- Wave 3: enterprise app-layer symptoms (auth/proxy/mail — bridge to EIT101
  services via the proven `br-eitcorp` seam pattern, or lightweight stand-ins).
- AI-assisted grading of transcripts against rubrics.
- Parameterization engine v2 (randomized fault location as a first-class feature
  rather than per-scenario opt-in).

Dependencies: 0.x strictly first (0.2 can sink the whole reset design). Phase 1
before 2, 2 before 3. Phase 4.1 can draft in parallel with Phase 3; 4.2 needs
Phase 3 done.

---

## Status log

| Date | Item | Status / notes |
|------|------|----------------|
| 2026-07-12 | Plan created | Requirements session with Joe (see decided-requirements block). Confirmed same day: all build work happens on the lab host / via SSH, CLI-only. Nothing started; next action is 0.0. |
