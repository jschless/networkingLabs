# Networking Labs — Authoring Guide

This is the **contract** for writing a lab README in `labs/`. It is the
ContainerLab counterpart to `enterprise-it-101/AUTHORING.md` — same teaching
philosophy, adapted to router labs and GitHub-renderable markdown.

---

## 1. A lab is a practice environment, not a tutorial

> **A tutorial hands the student commands to transcribe. A lab gives the
> student an objective and makes them produce the commands.**

Transcription produces the *illusion* of competence. Generation — struggling
to produce a config, predicting an outcome, diagnosing a failure — produces
durable learning. Every rule below exists to force generation over
transcription.

Concretely, a README fails this contract when:

- working configuration appears in the open, with nothing for the student to
  figure out;
- a "Show configuration" toggle is the *only* content of a step — an answer
  key with a lid, no objective or hints to attempt it from;
- the README narrates a failure *and* its fix in the same breath ("you'll see
  the route is inaccessible — add `next-hop-self`"), so the student never
  diagnoses anything.

## 2. Difficulty bands

Each task sits in one of three bands. A lab ramps **guided → hinted → open**.

| Band | Student is given | Student produces | Share of lab |
|------|------------------|------------------|--------------|
| **Guided** | The exact command, visible | Nothing — run and observe | Setup only. ≤ 20% |
| **Hinted** | Objective + hints (command shape, key flags) | The config itself | The core. ~60–70% |
| **Open** | Objective or scenario only | The whole approach | End of lab + challenges. ~15–20% |

**Give vs. withhold:** withhold the thing the lab is *about* (if the lab
teaches OSPF areas, the student writes the area config); give the scaffolding
it is *not* about (deploy commands, `docker exec` boilerplate, addressing —
which is pre-configured in every lab anyway).

## 3. Required README structure

1. Title — `# <Topic> — Practice Lab`
2. One-paragraph intro — what you build and why it matters
3. **Topology** — diagram + link/node tables (addressing is given, always)
4. **How to use this lab** — the standard preamble (§4)
5. **Deploy** — exact commands, plus image-build prerequisites if any
6. **Tasks** — the body (§5)
7. **Verification** — end-state checklist the student can run
8. **Challenge questions** — 3–5, open-ended, **no answers provided**
9. **Troubleshooting** — symptom → cause → fix
10. (optional) **Extensions** — follow-on ideas beyond the validated workflow

## 4. The standard preamble

Copy this near-verbatim into every lab so the contract is identical across
the series:

```markdown
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
```

## 5. Task anatomy

Every Hinted/Open task uses this skeleton. Guided tasks may show their
commands in the open but keep an Objective and a check.

```markdown
## Task N — <imperative title>

**Objective:** <what to achieve and the success condition, 1–2 sentences>

**Predict first:** <a checkable question to answer before configuring —
"will the session establish?", "how many routes will r4 have?">

<details>
<summary>Hints</summary>

- <command shape, key keyword, where in the CLI tree it lives>
- <enough to unblock, not enough to remove the thinking>

</details>

<details>
<summary>Solution</summary>

```text
<full, correct, validated configuration>
```

</details>

<details>
<summary>Check your work</summary>

<what correct output looks like AND the mechanism it reveals; resolve the
Predict question here. "It worked" is not a check.>

</details>
```

Rules:

- **Objective** — imperative and specific: "Form an eBGP session between r1
  and r2 and advertise both loopbacks", not "Let's explore BGP".
- **Predict first** — only where there is a real question with a checkable
  answer (a gotcha, a count, a yes/no with a reason). Don't bolt a fake
  prediction onto a mechanical task.
- **Hints** — flag-level for Hinted tasks; one nudge at most for Open tasks.
  Point at `?` completion, `show` commands, and the *shape* of the answer.
- **Solution** — always collapsed, always validated against a live deploy.
  Never the first thing the student sees, never duplicated elsewhere.
- **Check your work** — the highest-value block: describe the expected
  output *and* explain why it proves the mechanism.

Use HTML `<details>`/`<summary>` (not mkdocs `???` admonitions): lab READMEs
are read on GitHub and included into the docs site, and `<details>` renders
in both. Keep a blank line after `<summary>` and around fences so GitHub
renders the markdown inside.

## 6. Depth requirements

**Break-It:** at least one task per lab deliberately breaks a working setup
and has the student diagnose it **from the symptom** — ideally one where the
symptom points at the wrong layer (a BGP session stuck in `Active` because of
an ACL; an OSPF adjacency stuck in `ExStart` because of MTU). End with the
repair and a re-verification. Debug labs satisfy this by construction.

**Make the invisible visible:** at least one task should expose something
otherwise taken on faith — a `tcpdump` of hellos or the TCP/179 handshake,
the LSDB/BGP table inspected directly, a comparison that reveals a boundary
(stub vs. totally-stubby; before/after `next-hop-self`).

## 7. Challenge questions

End every lab with 3–5 open-ended questions, **no answers provided**. They
test transfer, not recall: rank, diagnose, or design — "your iBGP mesh is
growing past 20 routers; what breaks operationally and what are your two
options?", not "what does next-hop-self do?". They must be answerable from
the lab plus reasoning, no outside lookup.

## 8. Accuracy

Solution and check blocks are a promise. Every command behind a Solution
toggle must have been run against a live deployment of *this* lab; every
"Check your work" claim must match real output. Note environment-sensitive
behavior (FRR vs. EOS defaults, `ebgp-requires-policy`) in the check block —
turn the caveat into a lesson. A converted or new lab is not done until it
has been deployed clean and walked end to end.
