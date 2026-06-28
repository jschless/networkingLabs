# Enterprise IT 101 — Lab Authoring Guide

This is the **contract** for building a lab in this series. `DESIGN.md` says
*what* the curriculum covers; this file says *how* each lab is built so that
every lab teaches the same way and at a predictable level of difficulty.

If you are creating or revising a lab, follow this document exactly. Lab 01
(`labs/01-active-directory/`) is the reference implementation — when in doubt,
match it.

---

## 1. What a lab is (and is not)

A lab is a **practice environment**, not a tutorial. The difference is the
single most important rule in this guide:

> **A tutorial hands the student commands to transcribe. A lab gives the
> student an objective and makes them produce the commands.**

Transcription produces the *illusion* of competence — the student feels
successful but retains little, because they never had to retrieve anything.
Generation (struggling to produce an answer, predicting an outcome, diagnosing
a failure) produces durable learning. Every design rule below exists to force
generation over transcription.

A lab is **done** when a student who has never seen the technology can, by
working through it, reach the point where they could perform the same task in
production *without the lab open in front of them*.

---

## 2. The difficulty contract

Every lab must hit this difficulty profile. State the target time in the doc
header and make the content actually fill it.

### 2.1 The three difficulty bands

Each **task** within a lab sits in one of three bands. A well-formed lab moves
through them in order — guided early, open late.

| Band | What the student is given | What they must produce | Use it for |
|------|---------------------------|------------------------|------------|
| **Guided** | The exact command (visible), with explanation | Nothing — they run it and observe | One-shot, error-prone, or uninteresting setup (e.g. domain provision). **Max ~20% of a lab.** |
| **Hinted** | Objective + hints (man pages, flag names, the shape of the answer) | The command itself, from the hints | The core of the lab. **~60–70% of tasks.** |
| **Open** | Objective only, or a scenario/question | The whole approach, with no given answer | The end of the lab and the challenge questions. **~15–20%.** |

A lab that is all-Guided is a tutorial (reject it). A lab that is all-Open is a
homework problem with no scaffolding (also reject it). The ramp is the point.

### 2.2 The "give vs. withhold" rule

For any given task, decide what to give by asking: **is this where the learning
is?**

- **Withhold** (make it Hinted/Open) the thing the lab is *about*. If the lab
  teaches LDAP, the student must construct the `ldapsearch` query.
- **Give** (make it Guided) the scaffolding the lab is *not* about. Bind-mounts,
  one-time provisioning, `docker exec` boilerplate, and anything that fails
  destructively if typed wrong can be handed over.

When you give a command, give it once. Do not restate the same command in three
places — the verification section should re-test outcomes, not re-paste tasks.

### 2.3 Time calibration

- Target **2–3 hours** for a standard lab (1.5–2 for a light one, 3–4 for a
  capstone). State it in the header.
- A lab that takes 30 minutes of copy-paste is mis-calibrated even if it "covers"
  the material. Pure transcription is fast and teaches nothing — the time must
  come from *thinking* (predicting, diagnosing, exploring), not from typing.
- The required **Break-It task** and the **Challenge Questions** (§4) are what
  make the time real. They are not optional padding.

---

## 3. Required document structure

Every lab `README.md` uses these sections **in this order**. Sections marked
*required* must be present in every lab.

1. **Title** — `# Lab NN — <Topic>` *(required)*
2. **One-paragraph intro** — what you build and why it matters *(required)*
3. **Topology** — ASCII diagram + a container table (name / image / IP / role) *(required)*
4. **How to use this lab** — the practice-lab preamble: predict-first, reveal-solution-after, observe-don't-just-verify. *(required — copy near-verbatim from Lab 01 so the contract is identical across the series)*
5. **Prerequisites** — image builds, prior labs *(required)*
6. **Deploy / Destroy** — the exact `docker compose` commands *(required)*
7. **What is pre-built / What you configure** — sets expectations *(required)*
8. **Tasks** — the body of the lab (see §4) *(required)*
9. **Verification Checklist** — outcome re-tests the student can run at the end *(required)*
10. **Challenge Questions** — open-ended, no answers given *(required)*
11. **Key Concepts** — the durable mental models, in tables/short prose *(required)*
12. **Troubleshooting** — symptom → cause → fix table *(required)*
13. **What's Next** — tie outcomes to specific upcoming labs *(required)*

Keep this order. A student moving between labs should never have to hunt for a
section.

---

## 4. Task anatomy

This is the core of the format. **Every Hinted/Open task uses this exact
skeleton.** Guided tasks may omit Hints/Solution but must keep Objective and
Check.

```markdown
## Task N — <imperative title>

**Objective:** <one or two sentences: what to achieve and the success condition>

??? question "Predict first"
    <a concrete question the student must answer BEFORE running anything.
    Must have a checkable answer. Prefer "how many / which / will X happen"
    over "think about". Include a deliberate gotcha when one exists.>

??? note "Hints"
    - <point at `--help`, a man page, a flag name, the shape of the answer>
    - <enough to unblock, not enough to remove the thinking>

??? note "Solution"
    ```bash
    <the full, correct, copy-pasteable command(s)>
    ```

??? success "Check your work"
    <what correct output looks like — AND why it matters. Connect the result
    back to the concept. This is where you teach, not just confirm. Reveal
    the answer to the Predict question here.>
```

Rules for each block:

- **Objective** — imperative and specific. "Create three users in the Employees
  OU" not "Let's explore user creation."
- **Predict first** — must be *checkable*. The student should be able to grade
  their own prediction in the Check block. Build in the gotcha when the real
  answer is surprising (Lab 01 Task 4: "you said 3 users — there are 6, here's
  why `krbtgt` matters").
- **Hints** — calibrated to the difficulty band. Hinted tasks get flag-level
  hints; Open tasks get a scenario and maybe one nudge.
- **Solution** — always behind a collapsed `??? note`. Always correct and
  runnable (see §7). Never the first thing the student sees.
- **Check your work** — the highest-value block. It must do two things: (1)
  describe correct output, (2) explain the *mechanism* the output reveals.
  "It worked" is not a Check; "you now have two tickets — the second is a
  service ticket, which is single sign-on in action" is.

---

## 5. The two depth requirements

A lab that only walks the happy path teaches recipes, not understanding. Every
lab must include both of the following.

### 5.1 A required "Break-It" task

At least one task must **deliberately break a working system and have the
student diagnose it from symptoms.** Not optional, not an appendix.

- Break something the *previous* tasks depended on, so the student feels the
  dependency.
- Have them diagnose **from the symptom**, ideally one where the error message
  points at the wrong layer (Lab 01: deleting a DNS SRV record produces a
  *Kerberos* error). Symptom/cause mismatch is the essence of real
  troubleshooting.
- Always end with the **repair** and a re-verification.

### 5.2 Make an invisible mechanism visible

At least one task must expose something the student would otherwise take on
faith. Examples:

- A `tcpdump`/`tshark` capture proving a claim ("the password never crosses the
  wire", "this traffic is plaintext, that's why we need TLS").
- Inspecting state directly (`klist` ticket cache, a lease database, a JWT's
  decoded claims, an ACL).
- A comparison that reveals a boundary (anonymous vs. authenticated query;
  cached vs. live credentials).

If the lab makes a claim about *why* something matters, there should be a task
where the student *observes* it being true.

---

## 6. Challenge Questions

End every lab with **3–5 open-ended questions with no answers provided.** These
test transfer, not recall. Good challenge questions:

- Ask the student to **rank, diagnose, or design**, not to define.
- Reference scenarios the lab set up but didn't explicitly answer ("a user can
  `kinit` but can't reach a share — list three things you'd check").
- Include at least one **design-extension** question that previews a future lab
  or a production decision ("you add a second DC — what must clients do?").
- Are answerable from what the lab taught + reasoning, never requiring outside
  lookup.

Do not provide solutions. If you feel the urge to, the question is probably a
recall question in disguise — rewrite it.

---

## 7. Accuracy and verification (non-negotiable)

The `Solution` and `Check your work` blocks are a promise to the student. A
wrong command behind a Solution toggle is worse than no toggle at all.

- **Every command in a Solution block must be run against a live deployment**
  before the lab ships. No exceptions for "obviously correct" commands —
  vendor CLIs are full of surprising argument orders (e.g. `samba-tool dns`
  SRV data is `target port priority weight`).
- **Every "Check your work" claim must match real output.** If you say six
  users appear, deploy and count them.
- **Destructive/break commands must be exact-match safe.** If a command needs an
  existing record's fields to match (delete, modify), tell the student to query
  the real values first rather than hard-coding them.
- Note any command that is environment-sensitive (host port conflicts, things
  that behave differently with a pinned config vs. discovery) and say so in the
  Check block — turn the caveat into a lesson.
- **Host-run in-place edits must be portable to BSD/macOS sed.** GNU `sed -i 's/…'`
  (no backup-suffix arg) silently fails on macOS, where `-i` requires an argument.
  For a command the student runs **on their own machine** (e.g. editing a file
  under `configs/` before `up`), use `perl -i -pe 's/…'` instead — it behaves
  identically on Linux and macOS. This does **not** apply to `docker exec … sed -i`
  commands: those run inside the Linux container images where GNU sed is correct
  (and `perl` may be absent), so leave them as `sed`.

A lab is not "done" until it has been deployed clean (`down -v` then `up`) and
walked end to end.

---

## 8. Infrastructure conventions

These keep the series consistent and the cumulative state working. See
`DESIGN.md` §"Design principles" for the rationale.

- **Docker Compose, not ContainerLab.** Service-oriented labs.
- **Cumulative state.** Labs 1–4 build the foundation; later labs extend it via
  `docker-compose.override.yml` rather than starting from zero.
- **Single network.** `lab-corp`, `10.100.0.0/16`. Respect the subnet plan:
  `.1.x` core, `.2.x` apps, `.3.x` ops, `.10.x` workstations, `.20.x` network
  devices. Assign static IPs from the right band.
- **Local image builds only** — no registry dependency. Custom images live in
  `enterprise-it-101/images/<name>/`. Reuse `workstation:local` as the standard
  client across labs; don't fork a new client image per lab without reason.
- **Pre-provision in entrypoints for Labs 02+**, but have Lab 01 provision
  manually (the foundation is worth doing by hand once).
- **Naming.** Containers get role-based names (`dc1`, `admin-ws`, `mail1`,
  `radius1`). Match `DESIGN.md`'s per-lab container tables.
- **Tooling in images.** If a task needs a tool (`tcpdump`, `ldap-utils`,
  `swaks`), add it to the image — don't assume it's present and don't have the
  student `apt-get` it mid-lab.
- **Don't publish container ports to the host except for browser-reached GUIs.**
  Containers talk to each other over the `lab-corp` network and the student
  reaches CLIs via `docker exec`, so service ports never need a host mapping.
  Publishing them invites collisions that block `docker compose up` on the
  student's machine — `53:53` in particular always clashes with the host DNS
  resolver (mDNSResponder / systemd-resolved). Only map a host port for a web UI
  the student opens in a browser (LAM, Keycloak, Grafana, Wazuh).
- **Authenticated LDAP without a TLS cert uses Kerberos GSSAPI, not a simple
  bind.** Samba AD rejects cleartext simple binds (`ldap_bind: Strong(er)
  authentication required ... Transport encryption required`), and there is no
  CA until Lab 03. The working pattern is `kinit <user>` then
  `ldapsearch -Y GSSAPI -H ldap://<dc-fqdn> ...` (no `-D`/`-w`). GSSAPI also
  needs `SASL_NOCANON on` in the client's `/etc/ldap/ldap.conf` (baked into
  `workstation:local`) — the lab DCs have no PTR records, so SASL's reverse-DNS
  canonicalisation would request a non-existent SPN (`ldap/<ip>`) and fail with
  "Server not found in Kerberos database". Reach for a simple bind only once
  LDAPS is available.

---

## 9. Docs integration (mkdocs)

Every lab gets a thin doc page that includes the lab's own README — the README
in the lab directory is the **single source of truth**.

1. Add a page under `docs/tracks/enterprise-it-101/NN-<slug>.md` using the
   `include-markdown` pattern (copy Lab 01's page):
   ```markdown
   ---
   title: "NN <Topic>"
   ---

   !!! tip "Practice Lab"
       <one-line summary>

   !!! note "Platform"
       Docker Compose — custom `<image>:local` images

   {%
     include-markdown "../../../enterprise-it-101/labs/NN-<slug>/README.md"
   %}
   ```
2. Add the page to the `Enterprise IT 101` nav block in `mkdocs.yml`.
3. Add the lab to the table in `docs/tracks/enterprise-it-101/index.md` and the
   series `enterprise-it-101/README.md`.

Never duplicate lab content into the docs page — always `include-markdown`.

---

## 10. Pre-publish checklist

A lab is not finished until every box is checked:

```
Content
[ ] Header states target duration; content actually fills it with thinking, not typing
[ ] ≤20% Guided tasks, ~60–70% Hinted, ~15–20% Open — ramp is guided→open
[ ] Every Hinted/Open task has Objective + Predict + Hints + Solution + Check
[ ] Every "Check your work" explains the mechanism, not just "it worked"
[ ] At least one required Break-It task with symptom-first diagnosis + repair
[ ] At least one task makes an invisible mechanism visible (capture/inspect/compare)
[ ] 3–5 Challenge Questions, open-ended, no answers given
[ ] All 13 required sections present, in order

Correctness (deploy and walk it)
[ ] Custom images build clean
[ ] `down -v` then `up` brings the lab up from scratch
[ ] Every Solution command runs and succeeds on the live deployment
[ ] Every Check claim matches actual output (counts, names, errors)
[ ] Break/delete commands are exact-match safe (query-first where needed)
[ ] Required tools are baked into images
[ ] No host port mappings except browser-reached GUIs (no `53:53`, etc.)
[ ] Authenticated LDAP uses GSSAPI until LDAPS exists (no cleartext simple binds)

Integration
[ ] Static IPs follow the subnet plan; container names match DESIGN.md
[ ] Cumulative state preserved (override file extends the foundation)
[ ] mkdocs page added (include-markdown), nav updated, index/README tables updated
```

---

## Reference

`labs/01-active-directory/README.md` is the canonical example of every rule in
this guide. Read it before authoring a new lab, and match its structure, tone,
and difficulty calibration.
